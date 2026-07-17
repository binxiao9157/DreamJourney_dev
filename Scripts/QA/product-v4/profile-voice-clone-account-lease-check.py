#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = (
    "DreamJourney/Sources/Modules/Profile/"
    "ProfileVoiceCloneShellViewController.swift"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source = (ROOT / SOURCE_PATH).read_text()
    snippets = (
        "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
        "private var viewAccountLease: AccountLease?",
        "private var viewDigitalHumanContext: DigitalHumanContext?",
        "captureViewAccountLease()",
        "validateViewOperation(at: .request)",
        "validateViewOperation(at: .commit)",
        "validateViewOperation(at: .runtime)",
        "validateViewOperation(at: .ui)",
        "playPreviewAudio(",
        "accountLease: AccountLease",
        "stopPreviewRuntime",
    )
    for snippet in snippets:
        require(snippet in source, f"profile voice clone lease missing: {snippet}")

    require(
        re.search(
            r"documentPicker\([\s\S]*?validateViewOperation\(at: \.ui\)"
            r"[\s\S]*?trainVoice",
            source,
        )
        is not None,
        "document picker result must be fenced before voice training",
    )
    require(
        re.search(
            r"requestVoiceCloneSynthesis\([\s\S]*?"
            r"validateViewOperation\(at: \.runtime\)",
            source,
        )
        is not None,
        "preview synthesis callback must retain the view lease",
    )

    print("Profile voice clone AccountLease check passed")


if __name__ == "__main__":
    main()
