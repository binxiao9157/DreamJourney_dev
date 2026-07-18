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
    archive = read(
        "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
    )
    time_letter = read(
        "DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift"
    )
    audio = read(
        "DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift"
    )
    legacy_capture = read(
        "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
    )

    require_all(
        archive,
        (
            "private var photoPickerAccountLease: AccountLease?",
            "captureMediaAccountLease()",
            "validateMediaAccountLease(accountLease, at: .commit)",
            "validateMediaOperation(",
            "archiveContext: DigitalHumanContext",
            "private func saveImageToArchive(",
            "analyzePhotoArchiveItemIfPossible(",
            "accountLease: AccountLease",
        ),
        "archive photo import lease",
    )
    require(
        re.search(
            r"imagePickerController\([\s\S]*?photoPickerAccountLease[\s\S]*?"
            r"validateMediaAccountLease\(accountLease, at: \.ui\)",
            archive,
        )
        is not None,
        "archive picker delegate must validate its originating lease",
    )

    require_all(
        time_letter,
        (
            "private var imagePickerAccountLease: AccountLease?",
            "captureImagePickerAccountLease()",
            "validateImagePickerAccountLease(accountLease, at: .commit)",
            "commitSelectedImage(",
        ),
        "time-letter image lease",
    )

    require_all(
        audio,
        (
            "private var recordingAccountLease: AccountLease?",
            "captureRecordingAccountLease()",
            "validateRecordingAccountLease(accountLease, at: .timer)",
            "validateRecordingAccountLease(accountLease, at: .runtime)",
            "validateRecordingAccountLease(accountLease, at: .commit)",
            "startRecording(accountLease: AccountLease)",
            "discardStaleRecording",
        ),
        "audio recorder lease",
    )

    require_all(
        legacy_capture,
        (
            "private var mediaPickerAccountLease: AccountLease?",
            "captureMediaPickerAccountLease()",
            "validateMediaPickerOperation(",
            "savePhotoToLocal(",
            "accountLease: AccountLease",
            "validateMediaPickerAccountLease(accountLease, at: .commit)",
        ),
        "legacy photo capture lease",
    )

    print("Media capture AccountLease check passed")


if __name__ == "__main__":
    main()
