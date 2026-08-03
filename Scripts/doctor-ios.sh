#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0
WARNINGS=0

log() {
  printf '%s\n' "$*"
}

pass() {
  log "OK  $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  log "WARN $*"
}

fail() {
  ERRORS=$((ERRORS + 1))
  log "FAIL $*"
}

check_file() {
  local relative_path="$1"
  local label="$2"
  if [[ -f "$ROOT_DIR/$relative_path" ]]; then
    pass "$label: $relative_path"
  else
    fail "$label missing: $relative_path"
  fi
}

check_dir() {
  local relative_path="$1"
  local label="$2"
  if [[ -d "$ROOT_DIR/$relative_path" ]]; then
    pass "$label: $relative_path"
  else
    fail "$label missing: $relative_path"
  fi
}

xcconfig_value() {
  local key="$1"
  shift
  local file
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    awk -F= -v key="$key" '
      $0 !~ /^[[:space:]]*\/\// && $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value=$2
        sub(/[[:space:]]*\/\/.*/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    ' "$file"
  done
}

is_placeholder_or_empty() {
  local value="${1:-}"
  [[ -z "$value" ]] && return 0
  [[ "$value" == *"YOUR_"* ]] && return 0
  [[ "$value" == *"your-"* ]] && return 0
  [[ "$value" == *"<"* ]] && return 0
  [[ "$value" == *">"* ]] && return 0
  return 1
}

normalize_xcconfig_url() {
  local value="${1:-}"
  value="${value//:\/\$()\//:\/\/}"
  printf '%s' "$value"
}

check_secret_value() {
  local label="$1"
  local value="${2:-}"
  if is_placeholder_or_empty "$value"; then
    fail "$label is not configured"
  else
    pass "$label configured; value intentionally omitted"
  fi
}

check_plain_value() {
  local label="$1"
  local value="${2:-}"
  if is_placeholder_or_empty "$value"; then
    fail "$label is not configured"
  else
    pass "$label: $value"
  fi
}

backend_request() {
  local path="$1"
  local base_url="$2"
  local token="$3"
  [[ -n "$base_url" ]] || return 1
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipped backend $path"
    return 0
  fi
  if [[ -n "$token" ]]; then
    curl -fsS --max-time 8 \
      -H "X-API-Token: $token" \
      -H "Authorization: Bearer $token" \
      "$base_url$path" >/dev/null
  else
    curl -fsS --max-time 8 "$base_url$path" >/dev/null
  fi
}

log "DreamJourney iOS doctor"
log "Root: $ROOT_DIR"
log ""

check_dir "DreamJourney.xcworkspace" "Xcode workspace"
check_dir "DreamJourney.xcodeproj" "Xcode project"
check_file "Podfile.lock" "CocoaPods lockfile"
check_file "Pods/Manifest.lock" "CocoaPods install state"
check_dir "Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework" "Bundled Tencent digital human SDK"

log ""
log "Local configuration"

BACKEND_CONFIG="$ROOT_DIR/DreamJourney/Config/Backend.local.xcconfig"
SIGNING_CONFIGS=("$ROOT_DIR"/DreamJourney/Config/*.local.xcconfig)

check_file "DreamJourney/Config/Backend.local.xcconfig" "Backend local config"

DREAMJOURNEY_BACKEND_BASE_URL="${DREAMJOURNEY_BACKEND_BASE_URL:-$(xcconfig_value DREAMJOURNEY_BACKEND_BASE_URL "$BACKEND_CONFIG")}"
DREAMJOURNEY_BACKEND_BASE_URL="$(normalize_xcconfig_url "$DREAMJOURNEY_BACKEND_BASE_URL")"
DREAMJOURNEY_BACKEND_API_TOKEN="${DREAMJOURNEY_BACKEND_API_TOKEN:-$(xcconfig_value DREAMJOURNEY_BACKEND_API_TOKEN "$BACKEND_CONFIG")}"
DREAMJOURNEY_DEVELOPMENT_TEAM="${DREAMJOURNEY_DEVELOPMENT_TEAM:-$(xcconfig_value DREAMJOURNEY_DEVELOPMENT_TEAM "${SIGNING_CONFIGS[@]}")}"
DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="${DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER:-$(xcconfig_value DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER "${SIGNING_CONFIGS[@]}")}"

check_plain_value "DREAMJOURNEY_BACKEND_BASE_URL" "$DREAMJOURNEY_BACKEND_BASE_URL"
check_secret_value "DREAMJOURNEY_BACKEND_API_TOKEN" "$DREAMJOURNEY_BACKEND_API_TOKEN"
check_plain_value "DREAMJOURNEY_DEVELOPMENT_TEAM" "$DREAMJOURNEY_DEVELOPMENT_TEAM"
check_plain_value "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER" "$DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER"

pass "mobile Provider credentials: retired; runtime access stays behind the backend contract"

log ""
log "Backend reachability"

if ! is_placeholder_or_empty "$DREAMJOURNEY_BACKEND_BASE_URL"; then
  if backend_request "/health" "$DREAMJOURNEY_BACKEND_BASE_URL" ""; then
    pass "backend /health reachable"
  else
    warn "backend /health is not reachable from this machine"
  fi

  if is_placeholder_or_empty "$DREAMJOURNEY_BACKEND_API_TOKEN"; then
    warn "skipped /config/runtime because backend API token is not configured"
  elif backend_request "/config/runtime" "$DREAMJOURNEY_BACKEND_BASE_URL" "$DREAMJOURNEY_BACKEND_API_TOKEN"; then
    pass "backend /config/runtime reachable"
  else
    warn "backend /config/runtime is not reachable or rejected the configured token"
  fi
fi

log ""
log "Summary: $ERRORS error(s), $WARNINGS warning(s)"

if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi
