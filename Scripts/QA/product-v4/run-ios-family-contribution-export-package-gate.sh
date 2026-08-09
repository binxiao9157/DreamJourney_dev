#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
IOS_TEST_DESTINATION="${DJ_IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/tmp/product-v4/DerivedDataFamilyContributionExportPackageGate}"
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"

[[ -n "$LOCAL_BUNDLE_ID" && "$LOCAL_BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || {
  printf '%s\n' 'A non-shared LOCAL_BUNDLE_ID is required for this gate.' >&2
  exit 2
}
[[ -n "$LOCAL_DEVELOPMENT_TEAM" ]] || {
  printf '%s\n' 'LOCAL_DEVELOPMENT_TEAM is required for this gate.' >&2
  exit 2
}

python3 "$ROOT/scripts/QA/product-v4/family-contribution-export-package-check.py"

xcodebuild test \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$IOS_TEST_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testAccountDataExportArchiveRequiresZIPSignature \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests/testFamilyContributionContractsKeepMaterialAndOwnerScopeStrict \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
  DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
  CODE_SIGNING_ALLOWED=NO

printf '[ios-family-contribution-export-package-gate] passed\n'
