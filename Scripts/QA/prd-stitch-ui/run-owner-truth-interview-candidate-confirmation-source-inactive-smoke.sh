#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_VARIANT=source-inactive \
  "$SCRIPT_DIR/run-owner-truth-interview-candidate-confirmation-fail-closed-smoke.sh" "$@"
