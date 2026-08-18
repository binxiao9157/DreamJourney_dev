#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/dreamjourney-password-auth-client-smoke"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcrun swiftc \
  "$ROOT_DIR/DreamJourney/Sources/Services/BackendPasswordAuthentication.swift" \
  "$ROOT_DIR/Scripts/QA/product-v4/password-authentication-client-model-smoke.swift" \
  -o "$BUILD_DIR/password-authentication-client-model-smoke"

"$BUILD_DIR/password-authentication-client-model-smoke"
