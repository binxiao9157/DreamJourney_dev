#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash Scripts/verify_phase1.sh

echo "== MockDialogEngine =="
xcrun swiftc -D MOCK_DIALOG_VERIFY \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  DreamJourney/Sources/Services/DialogEngineProtocol.swift \
  DreamJourney/Sources/Services/MockDialogEngine.swift \
  DreamJourney/Sources/Services/DialogEngineFactory.swift \
  Scripts/MockDialogEngineVerify/main.swift \
  -o /tmp/dreamjourney_mock_dialog_verify
/tmp/dreamjourney_mock_dialog_verify

echo "== MockDialogEngine simulator typecheck =="
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -sdk "$SIM_SDK" -target arm64-apple-ios15.0-simulator -D MOCK_DIALOG_VERIFY -typecheck \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  DreamJourney/Sources/Services/DialogEngineProtocol.swift \
  DreamJourney/Sources/Services/MockDialogEngine.swift \
  DreamJourney/Sources/Services/DialogEngineFactory.swift \
  Scripts/MockDialogEngineVerify/main.swift

echo "== phase2 diff --check =="
git diff --check
git diff --cached --check
