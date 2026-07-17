#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/product-v4/token-family-client-model-smoke}"
STUB_DIR="$OUTPUT_DIR/keychain-access-stub"
BIN_PATH="$OUTPUT_DIR/token-family-client-model-smoke"

mkdir -p "$STUB_DIR"

swiftc \
  -parse-as-library \
  -emit-object \
  -emit-module \
  -module-name KeychainAccess \
  -emit-module-path "$STUB_DIR/KeychainAccess.swiftmodule" \
  "$SCRIPT_DIR/token-family-client-keychain-stub.swift" \
  -o "$STUB_DIR/KeychainAccess.o"

swiftc \
  -parse-as-library \
  -I "$STUB_DIR" \
  "$ROOT_DIR/DreamJourney/Sources/Services/BackendAuthSessionStore.swift" \
  "$SCRIPT_DIR/token-family-client-model-smoke.swift" \
  "$STUB_DIR/KeychainAccess.o" \
  -o "$BIN_PATH"

"$BIN_PATH"
