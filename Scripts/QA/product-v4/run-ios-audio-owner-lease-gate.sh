#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOSTED_BUILD_DESTINATION="${DJ_IOS_TEST_BUILD_DESTINATION:-generic/platform=iOS}"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-ios-audio-owner-lease-check.py"

MODEL_SMOKE_BINARY="$(mktemp "${TMPDIR:-/tmp}/audio-owner-lease-model.XXXXXX")"
trap 'rm -f "$MODEL_SMOKE_BINARY"' EXIT
swiftc \
  "$ROOT/DreamJourney/Sources/App/AudioOwnerLeaseModel.swift" \
  "$ROOT/DreamJourney/Sources/App/AudioOwnerLeaseCoordinator.swift" \
  "$ROOT/Scripts/QA/product-v4/audio-owner-lease-model-smoke.swift" \
  -o "$MODEL_SMOKE_BINARY"
"$MODEL_SMOKE_BINARY"

if [[ -n "${DJ_IOS_TEST_DESTINATION:-}" ]]; then
  xcodebuild test \
    -workspace "$ROOT/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$DJ_IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/AudioOwnerLeaseModelTests \
    CODE_SIGNING_ALLOWED=NO
  exit 0
fi

xcodebuild build-for-testing \
  -workspace "$ROOT/DreamJourney.xcworkspace" \
  -scheme DreamJourney \
  -configuration Debug \
  -destination "$HOSTED_BUILD_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
