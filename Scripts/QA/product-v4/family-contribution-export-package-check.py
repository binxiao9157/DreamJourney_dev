#!/usr/bin/env python3
"""Guard the C4 family-contribution and D1 ZIP export iOS closures."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FAMILY = ROOT / "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift"
PROFILE = ROOT / "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


def require(source: str, markers: tuple[str, ...], label: str) -> None:
    for marker in markers:
        if marker not in source:
            raise AssertionError(f"{label} marker missing: {marker}")


def main() -> None:
    flags = FLAGS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    family = FAMILY.read_text(encoding="utf-8")
    profile = PROFILE.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    require(
        flags,
        (
            "case ownerTruthFamilyContribution",
            ".ownerTruthFamilyContribution,",
            "private static let nonPersistentFeatures",
        ),
        "feature boundary",
    )
    if flags.index(".ownerTruthFamilyContribution,") < flags.index(
        "private static let nonPersistentFeatures"
    ):
        raise AssertionError("family contribution must remain non-persistent/default-off")

    require(
        client,
        (
            "struct FamilyContributionGrantContract",
            "struct FamilyContributionSubmissionContract",
            "struct FamilyContributionHandoffContract",
            "case candidatePendingReview",
            "case memoryCurrent",
            "func listOwnerFamilyContributionGrants(",
            "func listContributorFamilyContributionGrants(",
            "func createOwnerFamilyContributionGrant(",
            "func revokeOwnerFamilyContributionGrant(",
            "func submitFamilyContributionText(",
            "func submitFamilyContributionImage(",
            "func reviewOwnerFamilyContributionSubmission(",
            "func readOwnerFamilyContributionImage(",
            'path: "/v2/family-contribution/grants"',
            "family-contribution/grants/\\(pathComponent(grant.grantId))/image-upload-intents",
            "struct AccountDataExportArchiveContract",
            "func downloadAccountDataExportArchive(",
            "download?format=zip",
        ),
        "typed client",
    )
    require(
        family,
        (
            'button.isHidden = true',
            '"familyContributionCreateButton"',
            '"familyContributionReviewButton"',
            '"familyContributionAccessButton"',
            "FamilyContributionComposerViewController",
            "FamilyContributionReviewViewController",
            'self.submitButton.configuration?.title = "重新提交"',
            '可点击右上角重试',
            "readOwnerFamilyContributionImage(",
            "reviewOwnerFamilyContributionSubmission(",
            "openCandidateReview(",
            'case .memoryCurrent: return "已成为正式记忆"',
        ),
        "family UI",
    )
    require(
        profile,
        (
            "static func writeArchive(",
            "AccountDataExportTemporaryStore.writeArchive(",
            "downloadAccountDataExportArchive(",
            'fileExtension: "zip"',
            "FileProtectionType.complete",
            "retireLegacyUnscopedExports",
        ),
        "export archive",
    )
    require(
        tests,
        (
            "testAccountDataExportArchiveRequiresZIPSignature",
            "testFamilyContributionContractsKeepMaterialAndOwnerScopeStrict",
        ),
        "contract tests",
    )
    print("Family contribution and export package check passed")


if __name__ == "__main__":
    main()
