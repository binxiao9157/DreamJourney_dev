#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-echo-application-coordinator-check.py"
python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-echo-turn-reducer-check.py"

# The hosted test bundle links provider SDKs unavailable to SwiftPM. CI may pass
# a runnable simulator destination to execute the isolated coordinator and
# turn-admission tests. The latter proves that duplicate final ASR callbacks
# cannot dispatch a second Context/digital-human/delayed-reply turn.
if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/EchoApplicationCoordinatorTests \
    -only-testing:DreamJourneyTests/EchoTurnIntentReducerTests \
    -only-testing:DreamJourneyTests/EchoViewModelTurnAdmissionTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
