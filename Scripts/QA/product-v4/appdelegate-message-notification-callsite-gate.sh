#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-appdelegate-message-notification.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/appdelegate-message-notification-callsite-static-check.py

swiftc -parse-as-library \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyStore.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift \
  Scripts/QA/product-v4/appdelegate-message-notification-callsite-model-smoke.swift \
  -framework UserNotifications \
  -o "$BUILD_DIR/appdelegate-message-notification-callsite-model-smoke"

"$BUILD_DIR/appdelegate-message-notification-callsite-model-smoke"

echo "AppDelegate message/notification callsite gate passed"
