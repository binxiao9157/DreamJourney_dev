#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/Scripts/QA/product-v4"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/dreamjourney-clang-module-cache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-/tmp/dreamjourney-swift-module-cache}"
export PYTHONPYCACHEPREFIX="${PYTHONPYCACHEPREFIX:-/tmp/dreamjourney-python-cache}"

cd "$ROOT_DIR"

python3 "$SCRIPT_DIR/product-v4-canonical-source-check.py"
python3 "$SCRIPT_DIR/product-v4-links-check.py"
python3 "$SCRIPT_DIR/product-confirmed-digital-human-closure-check.py"
python3 "$SCRIPT_DIR/product-confirmed-time-letter-delayed-reply-closure-check.py"
python3 "$SCRIPT_DIR/product-confirmed-first-release-scope-check.py"
python3 "$SCRIPT_DIR/product-confirmed-echo-grounding-check.py"
python3 "$SCRIPT_DIR/product-confirmed-final-readiness-check.py"

"$SCRIPT_DIR/run-product-confirmed-message-center-gate.sh"
"$SCRIPT_DIR/run-ios-publication-default-off-shell-gate.sh"
swift "$ROOT_DIR/Scripts/QA/prd-stitch-ui/release-qa-package-check.swift" "$ROOT_DIR"

if [[ -n "${PRODUCT_CONFIRMED_RUNTIME_JSON:-}" || -n "${PRODUCT_CONFIRMED_RUNTIME_URL:-}" ]]; then
  readiness_args=(
    --code-gate backendFinalClosure
    --code-gate iosFinalClosure
    --code-gate genericIPhoneOSBuild
  )
  if [[ -n "${PRODUCT_CONFIRMED_RUNTIME_JSON:-}" ]]; then
    readiness_args+=(--runtime-json "$PRODUCT_CONFIRMED_RUNTIME_JSON")
  else
    readiness_args+=(--runtime-url "$PRODUCT_CONFIRMED_RUNTIME_URL")
  fi
  if [[ -n "${PRODUCT_CONFIRMED_DEVICE_EVIDENCE_JSON:-}" ]]; then
    readiness_args+=(--device-evidence-json "$PRODUCT_CONFIRMED_DEVICE_EVIDENCE_JSON")
  fi
  if [[ -n "${PRODUCT_CONFIRMED_READINESS_OUTPUT:-}" ]]; then
    readiness_args+=(--output "$PRODUCT_CONFIRMED_READINESS_OUTPUT")
  fi
  python3 "$SCRIPT_DIR/product-confirmed-final-readiness.py" "${readiness_args[@]}"
fi

echo "iOS PC-E2 product-confirmed final closure gate passed"
