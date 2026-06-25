#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
swift "$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift" "$ROOT_DIR"
