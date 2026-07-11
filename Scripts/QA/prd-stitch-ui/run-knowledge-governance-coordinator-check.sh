#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/knowledge-governance-coordinator-check.swift" "$ROOT_DIR"
