#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IOS_TEST_DESTINATION="${DJ_IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

python3 "$ROOT/scripts/QA/product-v4/product-v4-ios-owner-media-unified-creation-check.py"
xcodebuild test \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$IOS_TEST_DESTINATION" \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testArchiveCreationOptionsKeepOwnerTruthSourceHiddenByDefault \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testOwnerTruthMediaCreationPolicyRequiresExplicitProcessingChoice \
  CODE_SIGNING_ALLOWED=NO
