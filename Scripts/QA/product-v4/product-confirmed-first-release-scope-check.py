#!/usr/bin/env python3
"""Guard the product-confirmed PC-00-03 first-release visibility boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"PC-00-03 first-release scope check failed: {message}")


options = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
runtime = read("DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift")
contracts = read("DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")

closed_block = client.split("productClosedFeatures", 1)[1].split("]", 1)[0]
for marker in (
    ".archiveAudioUpload,",
    ".archiveVideoUpload,",
    ".kbliteUserSurface,",
    ".accountDataExport,",
):
    require(marker in closed_block, f"missing client product closure {marker}")

require("case kbliteUserSurface" in flags, "KBLite user surface needs a distinct feature")
require("case kbliteUserSurface" in runtime, "runtime must parse KBLite user-surface closure")
require("case accountDataExport" in runtime, "runtime must parse account-export closure")
require(
    "includesProductClosedMedia: Bool = false" in options,
    "ordinary creation options need an explicit default-off media boundary",
)
require(
    "includesProductClosedMedia: isUIQAArchiveHiddenBranchesEnabled" in archive,
    "only the isolated archive QA route may request audio/video options",
)
require(
    "isUIQAArchiveHiddenBranchesEnabled" in archive
    and ".kbliteUserSurface" in archive
    and "KnowledgeBaseViewController()" in archive,
    "KBLite must remain reachable only through the isolated QA branch",
)
require(
    "private var isAccountDataExportVisible: Bool {\n        false\n    }" in profile,
    "the client must expose no full-account export entry",
)
require(
    "注销前可导出个人数据副本" not in profile,
    "account deletion copy must not advertise a closed full-account export",
)

ordinary_owner_truth = options.split("if isOwnerTruthTextCaptureEnabled", 1)[1].split(
    "if isTimeLettersEnabled", 1
)[0]
require(
    ".ownerTruthPhotoCapture" in ordinary_owner_truth
    and ".ownerTruthDocumentCapture" in ordinary_owner_truth,
    "image and document creation must remain available",
)
require(
    "if includesProductClosedMedia" in ordinary_owner_truth,
    "audio/video options must sit behind the explicit internal-only switch",
)
require(
    "self == .image || self == .document" in contracts,
    "first-release external processing must remain image/document only",
)
require(
    "是否允许文档解析？" in archive and "允许文档解析" in archive,
    "document processing needs its own disclosure instead of audio copy",
)

print("PC-00-03 iOS first-release scope check passed")
