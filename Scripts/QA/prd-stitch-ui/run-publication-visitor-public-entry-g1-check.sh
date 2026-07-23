#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

swift "$SCRIPT_DIR/publication-visitor-public-entry-g1-check.swift" "$ROOT_DIR"

echo "Publication/visitor public-entry G1 gate passed"
