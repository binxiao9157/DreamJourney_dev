#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

swift "$SCRIPT_DIR/publication-default-off-shell-gate-check.swift" "$ROOT_DIR"
bash "$SCRIPT_DIR/run-ios-publication-management-scope-gate.sh"
bash "$SCRIPT_DIR/run-ios-publication-visitor-scope-gate.sh"
swift "$SCRIPT_DIR/publication-lifecycle-ios-scope-gate-check.swift" "$ROOT_DIR"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/release-policy-cache-contract-check.swift" "$ROOT_DIR"
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-release-policy-cache-model-smoke.sh"

if [[ "${RUN_XCODE_TESTS:-0}" == "1" ]]; then
  DESTINATION="${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"
  xcodebuild \
    -workspace "$ROOT_DIR/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -destination "$DESTINATION" \
    -only-testing:DreamJourneyTests/PublicationVisitorAccessTests \
    -only-testing:DreamJourneyTests/PublicationManagementAccessTests \
    -only-testing:DreamJourneyTests/PublicationLifecycleAccessTests \
    test
fi

echo "Publication default-off iOS shell gate passed"
