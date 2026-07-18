#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-ai-recording-lifecycle-forwarding-check.py"
python3 "$ROOT/Scripts/QA/product-v4/ai-recording-dialog-account-lease-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-consumer-inventory-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-lifecycle-event-forwarding-check.py"
bash "$ROOT/Scripts/QA/product-v4/run-account-private-media-store-gate.sh"
xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
