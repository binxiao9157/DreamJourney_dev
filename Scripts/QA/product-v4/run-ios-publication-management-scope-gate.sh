#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

swift "$SCRIPT_DIR/publication-management-ios-scope-gate-check.swift" "$ROOT_DIR"

echo "Publication management iOS scope gate passed"
