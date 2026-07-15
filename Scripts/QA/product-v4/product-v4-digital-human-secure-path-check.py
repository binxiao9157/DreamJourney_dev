#!/usr/bin/env python3
"""Guard WI-S0-03-05 Tencent digital-human mobile credential boundaries."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    boundary = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift")
    bridge = read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
    factory = read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift")
    runtime = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")

    require("let accessPath: String" in client, "digital-human runtime must parse accessPath")
    require("let mobileDirectAllowed: Bool" in client, "digital-human runtime must parse mobileDirectAllowed")
    require("let brokerStatus: String" in client, "digital-human runtime must parse brokerStatus")
    require("let decisionReasonCode: String?" in client, "digital-human runtime must parse decision receipt")
    require("var allowsScopedMobileSession: Bool" in client, "runtime capability needs a deny-by-default guard")
    require('accessPath == "scopedSessionCredential"' in client, "only scoped session access may enable mobile direct")
    require('brokerStatus == "verified"' in client, "unverified broker status must remain denied")
    require("var isUsableScopedSessionCredential: Bool" in client, "session credential must reject expired or incomplete contracts")

    require("let appKey: String" not in boundary, "SDK boundary still accepts a project-level appKey")
    require("let accessToken: String" not in boundary, "SDK boundary still accepts a project-level accessToken")
    require("VirtualmanParams(appkey:" not in bridge, "real bridge still initializes Tencent with static mobile credentials")
    require("credentialBrokerUnavailable" in bridge, "real bridge must fail closed without an approved adapter")

    require("allowsScopedMobileSession" in factory, "runtime factory must enforce broker capability")
    require("isUsableScopedSessionCredential" in factory, "runtime factory must enforce session credential usability")
    require("capability == nil" not in factory, "missing runtime capability must not implicitly authorize direct mobile")
    require("credentialBrokerUnavailable" in runtime, "cloud runtime must retain an explicit closed-path error")

    print("Product V4 digital-human secure path check passed: static Tencent mobile auth is retired")


if __name__ == "__main__":
    main()
