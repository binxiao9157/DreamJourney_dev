#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-owner-truth-media-runtime-smoke"
mkdir -p "$BUILD_DIR"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$BUILD_DIR/swift-module-cache"

xcrun swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/OwnerTruthMediaRuntimeCapability.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/owner-truth-media-runtime-capability-smoke.swift" \
  -o "$BUILD_DIR/owner-truth-media-runtime-capability-smoke"

"$BUILD_DIR/owner-truth-media-runtime-capability-smoke"

xcrun swift \
  "$ROOT_DIR/Scripts/QA/product-v4/owner-truth-media-public-admission-check.swift" \
  "$ROOT_DIR"
