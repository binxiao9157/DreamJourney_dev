#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-echo-runtime-session-coordinator-check.py"

MODEL_SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/echo-runtime-session-coordinator.XXXXXX")"
trap 'rm -f "$MODEL_SMOKE_BINARY"' EXIT
swiftc \
  "$ROOT/DreamJourney/Sources/App/AccountSessionActor.swift" \
  "$ROOT/DreamJourney/Sources/App/AccountLease.swift" \
  "$ROOT/DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift" \
  "$ROOT/Scripts/QA/product-v4/echo-runtime-session-coordinator-model-smoke.swift" \
  -o "$MODEL_SMOKE_BINARY"
"$MODEL_SMOKE_BINARY"

# The hosted test bundle links provider SDKs unavailable to SwiftPM. CI may pass
# a runnable simulator destination to execute the isolated coordinator tests.
if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/EchoRuntimeSessionCoordinatorTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
