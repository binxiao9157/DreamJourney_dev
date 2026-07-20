#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  DESTINATION="$DJ_IOS_TEST_DESTINATION"
else
  SIMULATOR_ID="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ { print $2; exit }')"
  if [[ -z "$SIMULATOR_ID" ]]; then
    echo "No booted iOS Simulator. Boot one or set DJ_IOS_TEST_DESTINATION." >&2
    exit 2
  fi
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-test-foundation-check.py"

xcodebuild test \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$DESTINATION" \
  -only-testing:DreamJourneyTests \
  CODE_SIGNING_ALLOWED=NO
