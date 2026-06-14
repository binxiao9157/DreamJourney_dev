#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BACKEND_PYTHON="python3"
if [ -x "DreamJourneyBackend/.venv/bin/python" ]; then
  BACKEND_PYTHON="DreamJourneyBackend/.venv/bin/python"
fi

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
  DreamJourney/Sources/Services/TimeMailbox/TimeMailboxEchoService.swift \
  DreamJourney/Sources/Services/TimeMailbox/TimeMailboxRepository.swift \
  Scripts/TimeMailboxVerify/main.swift \
  -o /tmp/dreamjourney_time_mailbox_verify
/tmp/dreamjourney_time_mailbox_verify

echo "== TimeMailbox notification =="
python3 Scripts/TimeMailboxNotificationVerify/main.py

echo "== TimeMailbox delayed delivery =="
python3 Scripts/TimeMailboxDeliveryDelayVerify/main.py

echo "== TimeMailbox automatic delivery refresh =="
python3 Scripts/TimeMailboxAutoDeliveryRefreshVerify/main.py

echo "== TimeMailbox backend sync =="
python3 Scripts/TimeMailboxBackendSyncVerify/main.py

echo "== TimeMailbox live evidence UI =="
python3 Scripts/TimeMailboxLiveEvidenceUIVerify/main.py

echo "== TimeMailbox payload privacy =="
python3 Scripts/TimeMailboxPayloadPrivacyVerify/main.py

echo "== TimeMailbox true backend flow =="
PYTHONPATH=DreamJourneyBackend STORE_BACKEND=memory "$BACKEND_PYTHON" Scripts/TimeMailboxTrueBackendFlowVerify/main.py

echo "== TimeMailbox knowledge metadata =="
python3 Scripts/TimeMailboxKnowledgeVerify/main.py

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

echo "== Conversation memory care history =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  Scripts/ConversationMemoryCareHistoryVerify/main.swift \
  -o /tmp/dreamjourney_conversation_memory_care_history_verify
/tmp/dreamjourney_conversation_memory_care_history_verify

echo "== CareDashboard snapshot selection =="
xcrun swiftc -D CARE_DASHBOARD_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  Scripts/CareDashboardSnapshotSelectionVerify/main.swift \
  -o /tmp/dreamjourney_care_snapshot_selection_verify
/tmp/dreamjourney_care_snapshot_selection_verify

echo "== CareDashboard backend sync =="
python3 Scripts/CareDashboardBackendSyncVerify/main.py

echo "== CareDashboard conversation-end publish =="
python3 Scripts/CareDashboardSessionPublishVerify/main.py

echo "== CareDashboard true backend flow =="
PYTHONPATH=DreamJourneyBackend STORE_BACKEND=memory "$BACKEND_PYTHON" Scripts/CareDashboardTrueBackendFlowVerify/main.py

echo "== CareDashboard data readiness UI =="
python3 Scripts/CareDashboardDataReadinessUIVerify/main.py

echo "== CareDashboard report readiness =="
python3 Scripts/CareDashboardReportReadinessVerify/main.py

echo "== CareDashboard speech signal =="
python3 Scripts/CareDashboardSpeechSignalVerify/main.py

echo "== CareDashboard member-specific publish =="
python3 Scripts/CareDashboardMemberPublishVerify/main.py

echo "== CareDashboard live evidence UI =="
python3 Scripts/CareDashboardLiveEvidenceUIVerify/main.py

echo "== CareDashboard backend access status UI =="
python3 Scripts/CareDashboardBackendAccessStatusUIVerify/main.py

echo "== CareDashboard share report UI =="
python3 Scripts/CareDashboardShareReportUIVerify/main.py

echo "== MemoryArchive backend sync =="
python3 Scripts/MemoryArchiveBackendSyncVerify/main.py

echo "== MemoryArchive image analysis proxy =="
python3 Scripts/MemoryArchiveImageAnalysisProxyVerify/main.py

echo "== MemoryArchive image analysis strict backend =="
python3 Scripts/MemoryArchiveImageAnalysisStrictBackendVerify/main.py

echo "== MemoryArchive image analysis retry =="
python3 Scripts/MemoryArchiveImageAnalysisRetryVerify/main.py

echo "== MemoryArchive voice knowledge =="
python3 Scripts/MemoryArchiveVoiceKnowledgeVerify/main.py

echo "== MemoryArchive voice transcript backfill =="
python3 Scripts/MemoryArchiveVoiceTranscriptBackfillVerify/main.py

echo "== MemoryArchive voice auto transcription =="
python3 Scripts/MemoryArchiveVoiceAutoTranscriptionVerify/main.py

echo "== MemoryArchive voice profile status UI =="
python3 Scripts/MemoryArchiveVoiceProfileStatusUIVerify/main.py

echo "== MemoryArchive voice import audio validation =="
swiftc -DMEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveModels.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift \
  Scripts/MemoryArchiveVoiceImportAudioValidationVerify/main.swift \
  -o /tmp/dreamjourney_memory_archive_voice_import_audio_validation_verify
/tmp/dreamjourney_memory_archive_voice_import_audio_validation_verify

echo "== MemoryArchive knowledge deposit UI =="
python3 Scripts/MemoryArchiveKnowledgeDepositUIVerify/main.py

echo "== MemoryArchive knowledge evidence =="
python3 Scripts/MemoryArchiveKnowledgeEvidenceVerify/main.py

echo "== MemoryArchive metadata-only deposit =="
python3 Scripts/MemoryArchiveMetadataOnlyDepositVerify/main.py

echo "== MemoryArchive privacy deposit UX =="
python3 Scripts/MemoryArchivePrivacyDepositUXVerify/main.py

echo "== MemoryArchive personality prompt UI =="
python3 Scripts/MemoryArchivePersonalityPromptUIVerify/main.py

echo "== MemoryArchive screenshot material =="
python3 Scripts/MemoryArchiveScreenshotMaterialVerify/main.py

echo "== MemoryArchive screenshot OCR =="
python3 Scripts/MemoryArchiveScreenshotOCRVerify/main.py

echo "== MemoryArchive conversation boundary =="
python3 Scripts/MemoryArchiveConversationBoundaryVerify/main.py

echo "== Family backend sync =="
python3 Scripts/FamilyBackendSyncVerify/main.py

echo "== DreamJourney backend auth =="
python3 Scripts/DreamJourneyBackendAuthVerify/main.py

echo "== Family member access state =="
xcrun swiftc \
  DreamJourney/Sources/Services/MemoryModel.swift \
  Scripts/FamilyMemberAccessStateVerify/main.swift \
  -o /tmp/dreamjourney_family_member_access_state_verify
/tmp/dreamjourney_family_member_access_state_verify

echo "== Family access control UI =="
xcrun swift Scripts/FamilyAccessControlUIVerify/main.swift

echo "== Family invitation code =="
python3 Scripts/FamilyInvitationCodeVerify/main.py

echo "== DigitalHuman startup reveal =="
python3 Scripts/DigitalHumanStartupRevealVerify/main.py

echo "== DigitalHuman dialog-end deposit =="
python3 Scripts/DigitalHumanDialogEndDepositVerify/main.py

echo "== DigitalHuman playback interruption =="
python3 Scripts/DigitalHumanPlaybackInterruptVerify/main.py

echo "== DigitalHuman playback policy =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift \
  Scripts/DigitalHumanPlaybackPolicyVerify/main.swift \
  -o /tmp/dreamjourney_digital_human_playback_policy_verify
/tmp/dreamjourney_digital_human_playback_policy_verify

echo "== DigitalHuman fallback UI =="
python3 Scripts/DigitalHumanFallbackUIVerify/main.py

echo "== DigitalHuman diagnostics gate =="
python3 Scripts/DigitalHumanDiagnosticsGateVerify/main.py

echo "== DigitalHuman diagnostics UI =="
python3 Scripts/DigitalHumanDiagnosticsUIVerify/main.py

echo "== DigitalHuman readiness =="
xcrun swiftc \
  DreamJourney/Sources/Services/AppConfiguration.swift \
  DreamJourney/Sources/Memoir/VolcEngineCredentialProvider.swift \
  DreamJourney/Sources/Services/VolcEngineRealtimeCredentialProvider.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift \
  DreamJourney/Sources/Services/DigitalHumanReadinessReport.swift \
  Scripts/DigitalHumanReadinessVerify/main.swift \
  -o /tmp/dreamjourney_digital_human_readiness_verify
/tmp/dreamjourney_digital_human_readiness_verify

echo "== DigitalHuman runtime log =="
python3 Scripts/DigitalHumanRuntimeLogVerify/main.py

echo "== DigitalHuman playback evidence store typecheck =="
xcrun swiftc -typecheck \
  DreamJourney/Sources/Services/DigitalHumanPlaybackEvidenceStore.swift

echo "== Conversation wellbeing limiter =="
xcrun swiftc \
  DreamJourney/Sources/Services/ConversationWellbeingLimiter.swift \
  Scripts/ConversationWellbeingLimiterVerify/main.swift \
  -o /tmp/dreamjourney_conversation_wellbeing_verify
/tmp/dreamjourney_conversation_wellbeing_verify

echo "== Conversation wellbeing UI =="
python3 Scripts/ConversationWellbeingUIVerify/main.py

echo "== Conversation wellbeing memory boundary =="
python3 Scripts/ConversationWellbeingMemoryBoundaryVerify/main.py

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

echo "== KBLite archive voice =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteArchiveVoiceVerify/main.swift \
  -o /tmp/dreamjourney_kblite_archive_voice_verify
/tmp/dreamjourney_kblite_archive_voice_verify

echo "== Memory archive voice profile =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveModels.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift \
  Scripts/MemoryArchiveVoiceProfileVerify/main.swift \
  -o /tmp/dreamjourney_memory_archive_voice_profile_verify
/tmp/dreamjourney_memory_archive_voice_profile_verify

echo "== Memory archive voice profile speaker resolve =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveModels.swift \
  DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift \
  Scripts/MemoryArchiveVoiceProfileSpeakerResolveVerify/main.swift \
  -o /tmp/dreamjourney_memory_archive_voice_profile_speaker_resolve_verify
/tmp/dreamjourney_memory_archive_voice_profile_speaker_resolve_verify

echo "== Memory archive voice training samples =="
python3 Scripts/MemoryArchiveVoiceTrainingSamplesVerify/main.py

echo "== Voice clone profile persistence =="
python3 Scripts/VoiceCloneProfilePersistenceVerify/main.py

echo "== DigitalHuman voice profile TTS =="
python3 Scripts/DigitalHumanVoiceProfileTTSVerify/main.py

echo "== KBLite archive material metadata =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteArchiveMaterialMetadataVerify/main.swift \
  -o /tmp/dreamjourney_kblite_archive_material_verify
/tmp/dreamjourney_kblite_archive_material_verify

echo "== KBLite source refs =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteSourceRefPropagationVerify/main.swift \
  -o /tmp/dreamjourney_kblite_source_ref_verify
/tmp/dreamjourney_kblite_source_ref_verify

echo "== KBLite import sanitizer =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteImportSanitizerVerify/main.swift \
  -o /tmp/dreamjourney_kblite_import_sanitizer_verify
/tmp/dreamjourney_kblite_import_sanitizer_verify

echo "== KBLite time mailbox =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteTimeMailboxVerify/main.swift \
  -o /tmp/dreamjourney_kblite_time_mailbox_verify
/tmp/dreamjourney_kblite_time_mailbox_verify

echo "== KBLite deposit status =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  Scripts/KBLiteDepositStatusVerify/main.swift \
  -o /tmp/dreamjourney_kblite_deposit_status_verify
/tmp/dreamjourney_kblite_deposit_status_verify

echo "== KnowledgeBase deposit status UI =="
python3 Scripts/KnowledgeBaseDepositStatusUIVerify/main.py

echo "== Dialog knowledge deposit feedback =="
python3 Scripts/DialogKnowledgeDepositFeedbackVerify/main.py

echo "== Dialog memory RAG payload =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  Scripts/DialogMemoryRAGPayloadVerify/main.swift \
  -o /tmp/dreamjourney_dialog_memory_rag_payload_verify
/tmp/dreamjourney_dialog_memory_rag_payload_verify

echo "== KBLite remote extraction evidence =="
python3 Scripts/KBLiteRemoteExtractionEvidenceVerify/main.py

echo "== KnowledgeBase source privacy UI =="
python3 Scripts/KnowledgeBaseSourcePrivacyUIVerify/main.py

echo "== KBLite entity quality =="
python3 Scripts/KBLiteEntityQualityVerify/main.py

echo "== KBLite prompt graph sanitization =="
python3 Scripts/KBLitePromptGraphSanitizationVerify/main.py

echo "== KBLite backend snapshot restore =="
python3 Scripts/KBLiteBackendSnapshotVerify/main.py

echo "== Backend Postgres KBLite persistence =="
PYTHONPATH=DreamJourneyBackend "$BACKEND_PYTHON" -m unittest DreamJourneyBackend.tests.test_postgres_store

echo "== KBLite user lifecycle =="
python3 Scripts/KBLiteUserLifecycleVerify/main.py

echo "== User identity stability =="
python3 Scripts/UserIdentityStabilityVerify/main.py

echo "== Conversation turn source refs =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  Scripts/ConversationTurnSourceRefVerify/main.swift \
  -o /tmp/dreamjourney_conversation_turn_source_ref_verify
/tmp/dreamjourney_conversation_turn_source_ref_verify

echo "== Local test data cleanup =="
python3 Scripts/LocalTestDataCleanupVerify/main.py

echo "== Family local test cleanup =="
python3 Scripts/FamilyLocalTestCleanupVerify/main.py

echo "== FamilyFootprint real-device timeline =="
swiftc \
  DreamJourney/Sources/Services/MemoryModel.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintTimeline.swift \
  Scripts/FamilyFootprintVerify/main.swift \
  -o /tmp/dreamjourney_family_footprint_verify
/tmp/dreamjourney_family_footprint_verify
python3 Scripts/FamilyFootprintIlluminationPolicyVerify/main.py

echo "== Roadshow mailbox seed cleanup marker =="
python3 Scripts/RoadshowMailboxSeedVerify/main.py

echo "== Real-device no-demo state =="
python3 Scripts/RealDeviceNoDemoStateVerify/main.py
python3 Scripts/RealDeviceNoDemoStateTokensVerify/main.py
python3 Scripts/RealDeviceRuntimeGateVerify/main.py

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
