#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IOS_TEST_DESTINATION="${DJ_IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/tmp/product-v4/DerivedDataOwnerExportDeletionSurfaceGate}"

swift "$ROOT/Scripts/QA/prd-stitch-ui/profile-family-account-lifecycle-check.swift" "$ROOT"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-owner-media-task-status-check.py"

xcodebuild test \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$IOS_TEST_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testAccountDataExportJobStatusStoreIsOwnerScopedAndResumable \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testAccountDataExportJobStatusPresentationKeepsFailuresExplicit \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testAccountDataExportRemainsDefaultOffAndFailsClosedWithoutServerPolicy \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testMediaTaskDeletionRetryRequeuesOnlySanitizedDeletionWork \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testOwnerTruthMediaTaskPresentationKeepsUploadAndProcessingFailuresDistinct \
  CODE_SIGNING_ALLOWED=NO

if [[ "${RUN_OWNER_EXPORT_DELETION_UIQA:-0}" == "1" ]]; then
  bash "$ROOT/Scripts/QA/product-v4/run-ios-owner-export-deletion-surface-uiqa-smoke.sh"
fi

printf '[owner-export-deletion-surface-gate] passed\n'
