#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-v4-memoir-owner-storage"

mkdir -p "$BUILD_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountSessionActor.swift" \
  "$ROOT_DIR/DreamJourney/Sources/App/AccountLease.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Memoir/MemoirModel.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Memoir/MemoirRepository.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/memoir-owner-storage-model-smoke.swift" \
  -o "$BUILD_DIR/memoir-owner-storage-model-smoke"

"$BUILD_DIR/memoir-owner-storage-model-smoke"
python3 "$ROOT_DIR/Scripts/QA/product-v4/memoir-owner-storage-static-check.py"

echo "Memoir owner storage gate passed"
