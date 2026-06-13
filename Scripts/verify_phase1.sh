#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== SafetyMonitor =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  Scripts/SafetyVerify/main.swift \
  -o /tmp/dreamjourney_safety_verify
/tmp/dreamjourney_safety_verify

echo "== TimeMailbox =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/TimeMailbox/TimeMailboxModels.swift \
  DreamJourney/Sources/Services/TimeMailbox/TimeMailboxRepository.swift \
  Scripts/TimeMailboxVerify/main.swift \
  -o /tmp/dreamjourney_time_mailbox_verify
/tmp/dreamjourney_time_mailbox_verify

echo "== TimeMailbox notification =="
python3 Scripts/TimeMailboxNotificationVerify/main.py

echo "== TimeMailbox backend sync =="
python3 Scripts/TimeMailboxBackendSyncVerify/main.py

echo "== MemoryArchive =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveModels.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift \
  Scripts/MemoryArchiveVerify/main.swift \
  -o /tmp/dreamjourney_memory_archive_verify
/tmp/dreamjourney_memory_archive_verify

echo "== CareDashboard =="
xcrun swiftc -D CARE_DASHBOARD_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalAnalyzer.swift \
  Scripts/CareDashboardVerify/main.swift \
  -o /tmp/dreamjourney_care_dashboard_verify
/tmp/dreamjourney_care_dashboard_verify

echo "== CareDashboard backend sync =="
python3 Scripts/CareDashboardBackendSyncVerify/main.py

echo "== MemoryArchive backend sync =="
python3 Scripts/MemoryArchiveBackendSyncVerify/main.py

echo "== MemoryArchive image analysis proxy =="
python3 Scripts/MemoryArchiveImageAnalysisProxyVerify/main.py

echo "== Family backend sync =="
python3 Scripts/FamilyBackendSyncVerify/main.py

echo "== Family invitation code =="
python3 Scripts/FamilyInvitationCodeVerify/main.py

echo "== DigitalHuman startup reveal =="
python3 Scripts/DigitalHumanStartupRevealVerify/main.py

echo "== KBLite =="
swift kblite_verify.swift

echo "== KBLite quick extract =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteQuickExtractVerify/main.swift \
  -o /tmp/dreamjourney_kblite_quick_extract_verify
/tmp/dreamjourney_kblite_quick_extract_verify

echo "== KBLite entity quality =="
python3 Scripts/KBLiteEntityQualityVerify/main.py

echo "== KBLite backend snapshot restore =="
python3 Scripts/KBLiteBackendSnapshotVerify/main.py

echo "== KBLite user lifecycle =="
python3 Scripts/KBLiteUserLifecycleVerify/main.py

echo "== Local test data cleanup =="
python3 Scripts/LocalTestDataCleanupVerify/main.py

echo "== diff --check =="
git diff --check
git diff --cached --check

echo "== pbxproj plist =="
plutil -lint DreamJourney.xcodeproj/project.pbxproj

echo "== iPhoneOS Debug build =="
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -sdk iphoneos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
