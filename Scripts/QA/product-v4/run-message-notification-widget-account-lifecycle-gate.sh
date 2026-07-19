#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

python3 Scripts/QA/product-v4/message-notification-widget-account-lifecycle-check.py
bash Scripts/QA/product-v4/run-echo-delayed-reply-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-in-app-message-owner-scope-gate.sh
python3 Scripts/QA/product-v4/message-notification-account-lease-check.py

git diff --check -- \
  DreamJourney/Sources/App/AccountLease.swift \
  DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyStore.swift \
  DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift \
  DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift \
  DreamJourney/Sources/Services/PushDeviceTokenStore.swift \
  DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift \
  Scripts/QA/product-v4/message-notification-widget-account-lifecycle-check.py \
  Scripts/QA/product-v4/run-message-notification-widget-account-lifecycle-gate.sh

echo "PASS: WI-S0-01-08B message/notification/push/widget lifecycle gate"
