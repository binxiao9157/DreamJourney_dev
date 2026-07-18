#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-echo-delayed-reply-callsite.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/echo-delayed-reply-callsite-static-check.py

swiftc -parse-as-library \
  Scripts/QA/product-v4/echo-delayed-reply-callsite-model-smoke.swift \
  -o "$BUILD_DIR/echo-delayed-reply-callsite-model-smoke"

"$BUILD_DIR/echo-delayed-reply-callsite-model-smoke"

echo "Echo delayed reply callsite gate passed"
