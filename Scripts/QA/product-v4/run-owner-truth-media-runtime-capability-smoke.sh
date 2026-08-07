#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-owner-truth-media-runtime-smoke"
mkdir -p "$BUILD_DIR"

xcrun swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/OwnerTruthMediaRuntimeCapability.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/owner-truth-media-runtime-capability-smoke.swift" \
  -o "$BUILD_DIR/owner-truth-media-runtime-capability-smoke"

"$BUILD_DIR/owner-truth-media-runtime-capability-smoke"
