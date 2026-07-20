#!/usr/bin/env bash
set -euo pipefail

# G0 model-only gate. This does not enable any runtime cutover path.
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

bash "$ROOT/Scripts/QA/product-v4/run-retirement-candidate-manifest-gate.sh"
python3 "$ROOT/Scripts/QA/product-v4/legacy-effect-cutover-fence-model-smoke.py"

echo "WI-S1-02-10 legacy effect cutover fence model G0 gate passed"
