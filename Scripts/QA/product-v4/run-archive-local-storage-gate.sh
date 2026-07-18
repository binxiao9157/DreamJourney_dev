#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-v4-archive-local-storage"

mkdir -p "$BUILD_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountSessionActor.swift" \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountLease.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/ArchiveLocalStorage.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/ArchiveMediaStore.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/archive-local-storage-model-smoke.swift" \
  -o "$BUILD_DIR/archive-local-storage-model-smoke"

swiftc -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountSessionActor.swift" \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountLease.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/ArchiveLocalStorage.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Modules/Archive/ArchiveMediaStore.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/archive-media-store-model-smoke.swift" \
  -o "$BUILD_DIR/archive-media-store-model-smoke"

"$BUILD_DIR/archive-local-storage-model-smoke"
"$BUILD_DIR/archive-media-store-model-smoke"
python3 "$ROOT_DIR/Scripts/QA/product-v4/archive-local-storage-static-check.py"
python3 "$ROOT_DIR/Scripts/QA/product-v4/archive-account-lease-static-check.py"
python3 "$ROOT_DIR/Scripts/QA/product-v4/media-capture-account-lease-check.py"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/archive-local-file-path-recovery-check.swift" "$ROOT_DIR"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift"

echo "Archive local storage gate passed"
