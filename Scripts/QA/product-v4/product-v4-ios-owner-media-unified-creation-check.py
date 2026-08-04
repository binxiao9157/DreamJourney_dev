#!/usr/bin/env python3
"""Guard the B2 unified owner media creation entry and privacy choices."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
OPTIONS = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
SHEET = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"
UIQA_SMOKE = ROOT / "Scripts/QA/product-v4/run-ios-owner-media-unified-creation-uiqa-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function: {name}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {name}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def main() -> None:
    options = OPTIONS.read_text(encoding="utf-8")
    archive = ARCHIVE.read_text(encoding="utf-8")
    sheet = SHEET.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")
    uiqa_smoke = UIQA_SMOKE.read_text(encoding="utf-8")

    require(
        "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]"
        in options,
        "public release creation baseline must remain text and photo",
    )
    for required in (
        "isOwnerTruthMediaCaptureEnabled: Bool = false",
        "options[0] = .ownerTruthTextCapture",
        "options[1] = .ownerTruthPhotoCapture",
        ".ownerTruthAudioCapture",
        ".ownerTruthDocumentCapture",
        ".ownerTruthVideoCapture",
        'title: "记录文字"',
        'title: "选择图片"',
        'title: "选择音频"',
        'title: "选择文档"',
        'title: "选择视频"',
        "case ownerTruthMedia(OwnerTruthMediaKind)",
        "case externalProcessingChoiceRequired",
        "case .audio, .document, .video:\n            return 50",
        'return "已保存，暂不分析"',
    ):
        require(required in options, f"unified creation contract missing: {required}")

    require(
        "isOwnerTruthMediaCaptureClosedPilotEnabled" in archive
        and "isServerPolicyManagedClosedPilotRouteAllowed(.ownerMediaCaptureV1)" in archive
        and "isOwnerTruthTextCaptureClosedPilotEnabled" in archive,
        "owner media entry must be authorized by captured server release policy",
    )
    require(
        "是否允许图片分析？" in archive
        and "是否允许语音转写？" in archive
        and "仅保存" in archive
        and "允许图片分析" in archive
        and "允许语音转写" in archive,
        "image and audio must require an explicit external processing choice",
    )
    require(
        "UIDocumentPickerViewController" in archive
        and "UIImagePickerController" in archive
        and "OwnerTruthMediaCreationPolicy.makeCommand" in archive
        and "OwnerTruthMediaTaskStore.shared.prepare" in archive
        and "OwnerTruthMediaTaskRecoveryCoordinator.shared.restore" in archive,
        "unified picker must enter the resumable Owner Truth media task path",
    )
    require(
        "fileURL.resourceValues(forKeys: [.fileSizeKey])" in archive
        and "OwnerTruthMediaCreationPolicyError.fileTooLarge" in archive,
        "document picker must reject oversized media before loading it into memory",
    )
    require(
        "fetchOwnerTruthTextSourceCaptureState" in archive
        and "expectedAuthorityEpoch: authorityEpoch" in archive,
        "media capture must use the current Vault authority epoch",
    )

    photo_card = function_body(archive, "photoCardTapped")
    audio_card = function_body(archive, "audioCardTapped")
    require(
        "applyArchiveKindFilter(.photo)" in photo_card
        and "presentPhotoEntry" not in photo_card,
        "photo feature card must remain browse-only",
    )
    require(
        "applyArchiveKindFilter(.audio)" in audio_card
        and "presentAudioEntry" not in audio_card,
        "audio feature card must remain browse-only",
    )

    for test_name in (
        "func testArchiveCreationOptionsKeepOwnerTruthSourceHiddenByDefault()",
        "func testOwnerTruthMediaCreationPolicyRequiresExplicitProcessingChoice()",
    ):
        require(test_name in tests, f"unified creation test missing: {test_name}")

    require(
        "options.count > 4 ? [.large()] : [.medium(), .large()]" in sheet,
        "five-option unified creator must open at the large detent",
    )
    for required in (
        'case ownerMediaUnifiedCreationSmoke = "DJRunOwnerMediaUnifiedCreationSmoke"',
        ".ownerMediaUnifiedCreationSmoke,",
    ):
        require(required in feature_flags, f"unified creation UIQA scenario missing: {required}")
    for required in (
        "runOwnerMediaUnifiedCreationSmoke()",
        "func runOwnerMediaUnifiedCreationSmoke(",
        '"persistentOwnerTruthWriteStarted": false',
        '"backendNetworkStarted": false',
    ):
        require(required in app_delegate, f"unified creation UIQA harness missing: {required}")
    for required in (
        "run-installable-simulator-uiqa.sh",
        "DJRunOwnerMediaUnifiedCreationSmoke",
        "owner-media-unified-creation-smoke-result.json",
        "01-owner-media-unified-creation.png",
    ):
        require(required in uiqa_smoke, f"unified creation UIQA script missing: {required}")

    print("Owner Truth unified media creation iOS check passed")


if __name__ == "__main__":
    main()
