#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
swift "$ROOT/Scripts/QA/prd-stitch-ui/formal-memory-library-check.swift" "$ROOT"
