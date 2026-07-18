#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-echo-delayed-reply-owner-scope.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/echo-delayed-reply-owner-scope-static-check.py

swiftc -parse-as-library \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyStore.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift \
  Scripts/QA/product-v4/echo-delayed-reply-owner-scope-model-smoke.swift \
  -framework UserNotifications \
  -o "$BUILD_DIR/echo-delayed-reply-owner-scope-model-smoke"

"$BUILD_DIR/echo-delayed-reply-owner-scope-model-smoke"

echo "Echo delayed reply owner-scope gate passed"
