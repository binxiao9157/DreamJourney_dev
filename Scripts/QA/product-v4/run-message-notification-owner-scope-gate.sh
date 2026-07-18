#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

Scripts/QA/product-v4/run-echo-delayed-reply-owner-scope-gate.sh
Scripts/QA/product-v4/run-echo-delayed-reply-callsite-gate.sh
Scripts/QA/product-v4/run-in-app-message-owner-scope-gate.sh
Scripts/QA/product-v4/appdelegate-message-notification-callsite-gate.sh
python3 Scripts/QA/product-v4/in-app-message-page-account-lease-static-check.py
swift Scripts/QA/product-v4/in-app-message-page-account-lease-model-smoke.swift
python3 Scripts/QA/product-v4/message-notification-account-lease-check.py

echo "Message/notification owner-scope gate passed"
