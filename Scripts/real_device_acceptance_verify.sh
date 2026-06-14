#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<USAGE
Usage: Scripts/real_device_acceptance_verify.sh <evidence-dir>

Verifies real-device acceptance evidence for the non-demo validation flow.
The evidence directory must exist and contain exported text evidence.
USAGE
}

EVIDENCE_DIR="${1:-${REAL_DEVICE_ACCEPTANCE_EVIDENCE_DIR:-}}"
if [[ -z "$EVIDENCE_DIR" ]]; then
  usage >&2
  exit 2
fi

python3 "$ROOT_DIR/Scripts/RealDeviceNoDemoStateVerify/main.py" "$EVIDENCE_DIR" --strict

printf 'Real device acceptance evidence verified: %s\n' "$EVIDENCE_DIR"
