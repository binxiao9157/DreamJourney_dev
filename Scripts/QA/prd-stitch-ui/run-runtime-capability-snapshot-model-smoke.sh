#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-runtime-capability-snapshot-smoke"
mkdir -p "$BUILD_DIR"

xcrun swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/runtime-capability-snapshot-model-smoke.swift" \
  -o "$BUILD_DIR/runtime-capability-snapshot-model-smoke"

"$BUILD_DIR/runtime-capability-snapshot-model-smoke"
