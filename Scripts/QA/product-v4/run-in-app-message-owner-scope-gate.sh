#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-in-app-message-owner-scope.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/in-app-message-owner-scope-static-check.py

swiftc -parse-as-library \
  DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift \
  Scripts/QA/product-v4/in-app-message-owner-scope-model-smoke.swift \
  -o "$BUILD_DIR/in-app-message-owner-scope-model-smoke"

"$BUILD_DIR/in-app-message-owner-scope-model-smoke"

echo "In-app message owner scope gate passed"
