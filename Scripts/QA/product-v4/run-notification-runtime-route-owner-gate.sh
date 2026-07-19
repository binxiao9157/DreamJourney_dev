#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dreamjourney-notification-runtime-route.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/notification-runtime-route-static-check.py
swiftc -parse-as-library \
  DreamJourney/Sources/App/AccountSessionActor.swift \
  DreamJourney/Sources/App/AccountLease.swift \
  Scripts/QA/product-v4/notification-runtime-route-owner-scope-model-smoke.swift \
  -framework CryptoKit \
  -o "$BUILD_DIR/notification-runtime-route-owner-scope-model-smoke"
"$BUILD_DIR/notification-runtime-route-owner-scope-model-smoke"
bash Scripts/QA/product-v4/appdelegate-message-notification-callsite-gate.sh
python3 Scripts/QA/product-v4/message-notification-widget-account-lifecycle-check.py

git diff --check -- \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/App/AppCoordinator.swift \
  DreamJourney/Sources/App/TabCoordinator.swift \
  DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift \
  DreamJourney/Sources/AppDelegate.swift \
  DreamJourney/Sources/SceneDelegate.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift \
  Scripts/QA/product-v4/echo-delayed-reply-owner-scope-model-smoke.swift \
  Scripts/QA/product-v4/echo-delayed-reply-owner-scope-static-check.py \
  Scripts/QA/product-v4/appdelegate-message-notification-callsite-model-smoke.swift \
  Scripts/QA/product-v4/appdelegate-message-notification-callsite-static-check.py \
  Scripts/QA/product-v4/notification-runtime-route-static-check.py \
  Scripts/QA/product-v4/notification-runtime-route-owner-scope-model-smoke.swift \
  Scripts/QA/product-v4/message-notification-widget-account-lifecycle-check.py \
  Scripts/QA/product-v4/run-message-notification-widget-account-lifecycle-gate.sh \
  Scripts/QA/product-v4/run-notification-runtime-route-owner-gate.sh

echo "PASS: WI-S1-03-09 notification/deeplink runtime owner gate"
