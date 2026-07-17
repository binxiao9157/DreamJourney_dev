#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing: {snippet}")


def main() -> None:
    voice = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
    tts = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")

    require_all(
        voice,
        (
            "private let accountLeaseRuntime: AccountLeaseRuntimePort",
            "private var trainingAccountLease: AccountLease?",
            "accountLeaseRuntime.capture(forSubjectId:",
            "validate(accountLease, at: .request).allowed",
            "validate(accountLease, at: .commit).allowed",
            "validate(accountLease, at: .timer).allowed",
            "validate(accountLease, at: .runtime).allowed",
            "validate(accountLease, at: .ui).allowed",
            "accountLease: AccountLease",
        ),
        "VoiceClone AccountLease contract",
    )
    require(
        re.search(r"startPollingStatus\([\s\S]*?accountLease:\s*AccountLease", voice) is not None,
        "voice training polling must retain the originating AccountLease",
    )
    require(
        re.search(r"queryStatus\([\s\S]*?accountLease:\s*AccountLease", voice) is not None,
        "voice status callbacks must retain the originating AccountLease",
    )

    require_all(
        tts,
        (
            "private let accountLeaseRuntime: AccountLeaseRuntimePort",
            "private struct SynthesisOperation",
            "accountLeaseRuntime.capture(forSubjectId: memoir.authorId)",
            "accountLease: AccountLease",
            "validate(accountLease, at: .request).allowed",
            "validate(accountLease, at: .commit).allowed",
            "validate(accountLease, at: .runtime).allowed",
            "validate(accountLease, at: .ui).allowed",
            "stagingFileURL",
            "commitSynthesisArtifacts",
        ),
        "Memoir TTS AccountLease contract",
    )

    print("Voice/TTS AccountLease check passed")


if __name__ == "__main__":
    main()
