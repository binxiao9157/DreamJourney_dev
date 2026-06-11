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

echo "== SafetyGuard =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  Scripts/SafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_safety_guard_verify
/tmp/dreamjourney_safety_guard_verify

echo "== PrivacyScope =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  Scripts/PrivacyScopeVerify/main.swift \
  -o /tmp/dreamjourney_privacy_scope_verify
/tmp/dreamjourney_privacy_scope_verify

echo "== MemoryPrivacyIntegration =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/Stage1MemoryFacade.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/MemoryPrivacyIntegrationVerify/main.swift \
  -o /tmp/dreamjourney_memory_privacy_integration_verify
/tmp/dreamjourney_memory_privacy_integration_verify

echo "== RemoteSafetyGuard =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
  Scripts/RemoteSafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_remote_safety_guard_verify
/tmp/dreamjourney_remote_safety_guard_verify

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
