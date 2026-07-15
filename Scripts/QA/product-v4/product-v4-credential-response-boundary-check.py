#!/usr/bin/env python3
"""Guard WI-S0-03-02 iOS credential response and local fallback boundaries."""

import os
import plistlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FORBIDDEN_APP_KEYS = (
    "DreamJourneyBackendAPIToken",
    "DeepSeekAPIKey",
    "VoiceCloneAPIKey",
    "VolcEngineAppKey",
    "VolcEngineAppToken",
    "VolcEngineAPIKey",
    "TencentDigitalHumanAppKey",
    "TencentDigitalHumanAccessToken",
)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def verify_release_app(app_path: Path) -> None:
    require(app_path.is_dir(), "CREDENTIAL_BOUNDARY_APP_PATH must point to a built .app")
    info_path = app_path / "Info.plist"
    require(info_path.is_file(), "built app Info.plist is missing")
    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    for key in FORBIDDEN_APP_KEYS:
        require(key not in info, f"built app Info.plist still contains forbidden key {key}")

    local_config_path = ROOT / "DreamJourney/Resources/LocalConfig.plist"
    secret_values = []
    if local_config_path.is_file():
        with local_config_path.open("rb") as handle:
            local_config = plistlib.load(handle)
        for key in FORBIDDEN_APP_KEYS:
            raw = local_config.get(key)
            if not isinstance(raw, str):
                continue
            value = raw.strip()
            if len(value) >= 8 and not value.startswith("YOUR_") and not value.startswith("$("):
                secret_values.append(value.encode("utf-8"))

    forbidden_key_bytes = [key.encode("utf-8") for key in FORBIDDEN_APP_KEYS]
    for file_path in app_path.rglob("*"):
        if not file_path.is_file():
            continue
        data = file_path.read_bytes()
        require(
            not any(key in data for key in forbidden_key_bytes),
            f"built app artifact contains a forbidden credential key label: {file_path.relative_to(app_path)}",
        )
        require(
            not any(value in data for value in secret_values),
            f"built app artifact contains a local credential value: {file_path.relative_to(app_path)}",
        )


def main() -> None:
    plist = read("DreamJourney/Resources/Info.plist")
    project = read("DreamJourney.xcodeproj/project.pbxproj")
    client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    dialog = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
    deepseek = read("DreamJourney/Sources/Memoir/DeepSeekService.swift")
    cloud_runtime = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
    echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

    for key in FORBIDDEN_APP_KEYS:
        require(f"<key>{key}</key>" not in plist, f"Info.plist still packages {key}")

    require("LOCAL_CONFIG_ALLOWED_KEYS" in project, "LocalConfig build phase needs an explicit allowlist")
    require("DreamJourneyBackendBaseURL" in project, "backend base URL must remain locally configurable")
    require("for key, value in local.items()" not in project, "LocalConfig must not merge every private value")

    require("DreamJourneyBackendAPIToken" not in client, "iOS client still reads the shared backend token")
    require('json["appkey"]' not in client and 'json["accesstoken"]' not in client, "iOS still parses Tencent static credentials")
    require('json["appToken"]' not in client and 'json["apiKey"]' not in client, "iOS still parses realtime static credentials")
    require("blockedStaticCredential" in client, "iOS must parse the blocked credential capability")

    require("VolcEngineAppKey" not in dialog and "VolcEngineAppToken" not in dialog, "Dialog engine still reads local Provider credentials")
    require("回落本地配置" not in dialog, "Dialog engine still advertises local credential fallback")
    require("providerCredentialBlocked" in dialog, "voice readiness must expose the security block")

    require("Authorization\": \"Bearer" not in deepseek, "DeepSeek client still constructs a direct Provider authorization header")
    require("DeepSeekAPIKey" not in deepseek, "DeepSeek client still reads a packaged API key")
    require("directProviderDisabled" in deepseek, "legacy DeepSeek direct calls need an explicit blocked error")
    require("响应体" not in deepseek and "原始内容" not in deepseek, "DeepSeek logs still expose full Provider payloads")

    require("contract.credential.appKey" not in cloud_runtime, "Tencent runtime still consumes static response credentials")
    require("credentialBrokerUnavailable" in cloud_runtime, "Tencent runtime needs an honest broker-unavailable failure")
    require("startDialogWithLocalVoiceFallback" not in echo, "Echo still starts the local static voice fallback")
    require("handleBlockedRealtimeVoice" in echo, "Echo needs an explicit safe blocked path")

    app_path = os.environ.get("CREDENTIAL_BOUNDARY_APP_PATH", "").strip()
    if app_path:
        verify_release_app(Path(app_path).expanduser().resolve())

    print("Product V4 credential response boundary check passed: iOS has no packaged/static Provider fallback")


if __name__ == "__main__":
    main()
