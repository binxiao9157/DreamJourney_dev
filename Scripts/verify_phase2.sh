#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash Scripts/verify_phase1.sh

echo "== CareDashboardShareReportUI =="
python3 Scripts/CareDashboardShareReportUIVerify/main.py

echo "== SecretConfig =="
python3 Scripts/SecretConfigVerify/main.py

echo "== BuildWarningCleanup =="
python3 Scripts/BuildWarningCleanupVerify/main.py

echo "== DigitalHumanAsset =="
python3 Scripts/DigitalHumanAssetVerify/verify_avatar_assets.py

echo "== DigitalHumanPlaybackPolicy =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift \
  Scripts/DigitalHumanPlaybackPolicyVerify/main.swift \
  -o /tmp/dreamjourney_digital_human_playback_policy_verify
/tmp/dreamjourney_digital_human_playback_policy_verify

echo "== DigitalHumanPlaybackEvidenceStore typecheck =="
xcrun swiftc -typecheck \
  DreamJourney/Sources/Services/DigitalHumanPlaybackEvidenceStore.swift

echo "== DigitalHumanFallbackUI =="
python3 Scripts/DigitalHumanFallbackUIVerify/main.py

echo "== RoadshowDemoSeed =="
xcrun swiftc -D CARE_DASHBOARD_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalAnalyzer.swift \
  DreamJourney/Sources/Services/RoadshowDemoSeed.swift \
  Scripts/RoadshowDemoVerify/main.swift \
  -o /tmp/dreamjourney_roadshow_demo_verify
/tmp/dreamjourney_roadshow_demo_verify

echo "== RoadshowRoute =="
xcrun swiftc -D CARE_DASHBOARD_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalAnalyzer.swift \
  DreamJourney/Sources/Services/RoadshowDemoSeed.swift \
  DreamJourney/Sources/Services/RoadshowDemoRoute.swift \
  Scripts/RoadshowRouteVerify/main.swift \
  -o /tmp/dreamjourney_roadshow_route_verify
/tmp/dreamjourney_roadshow_route_verify

echo "== RoadshowHostRouteUIContract =="
python3 Scripts/RoadshowHostRouteUIContractVerify/main.py

echo "== RoadshowEvidenceScaffold =="
python3 Scripts/RoadshowEvidenceScaffoldVerify/main.py

echo "== RoadshowDeviceSmokePreflight =="
python3 Scripts/RoadshowDeviceSmokePreflightVerify/main.py

echo "== RoadshowEvidencePackage =="
python3 Scripts/RoadshowEvidencePackageVerify/main.py

echo "== MockDialogEngine =="
xcrun swiftc -D MOCK_DIALOG_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  DreamJourney/Sources/Services/DialogEngineProtocol.swift \
  DreamJourney/Sources/Services/MockDialogEngine.swift \
  DreamJourney/Sources/Services/DialogEngineFactory.swift \
  Scripts/MockDialogEngineVerify/main.swift \
  -o /tmp/dreamjourney_mock_dialog_verify
/tmp/dreamjourney_mock_dialog_verify

echo "== DialogEndIntent =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  Scripts/DialogEndIntentVerify/main.swift \
  -o /tmp/dreamjourney_dialog_end_intent_verify
/tmp/dreamjourney_dialog_end_intent_verify

echo "== DialogMemoryGrounding =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  Scripts/DialogMemoryGroundingVerify/main.swift \
  -o /tmp/dreamjourney_dialog_memory_grounding_verify
/tmp/dreamjourney_dialog_memory_grounding_verify

echo "== SafetyGuard =="
xcrun swiftc \
  DreamJourney/Sources/Services/AppConfiguration.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
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
  DreamJourney/Sources/Memoir/MemoirModel.swift \
  Scripts/MemoryPrivacyIntegrationVerify/main.swift \
  -o /tmp/dreamjourney_memory_privacy_integration_verify
/tmp/dreamjourney_memory_privacy_integration_verify

echo "== KBLiteQuickExtract =="
xcrun swiftc -D MEMORY_PRIVACY_INTEGRATION_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  DreamJourney/Sources/Services/KBLiteManager.swift \
  Scripts/KBLiteQuickExtractVerify/main.swift \
  -o /tmp/dreamjourney_kblite_quick_extract_verify
/tmp/dreamjourney_kblite_quick_extract_verify

echo "== KBLiteEntityQuality =="
python3 Scripts/KBLiteEntityQualityVerify/main.py

echo "== SharePackagePrivacy =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/SharePackagePrivacyVerify/main.swift \
  -o /tmp/dreamjourney_share_package_privacy_verify
/tmp/dreamjourney_share_package_privacy_verify

echo "== RoadshowSharePackage =="
xcrun swiftc -D CARE_DASHBOARD_VERIFY \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalModels.swift \
  DreamJourney/Sources/Services/CareDashboard/CareSignalAnalyzer.swift \
  DreamJourney/Sources/Services/RoadshowDemoSeed.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/RoadshowSharePackageVerify/main.swift \
  -o /tmp/dreamjourney_roadshow_share_package_verify
/tmp/dreamjourney_roadshow_share_package_verify

echo "== RoadshowSharePackageSample =="
python3 Scripts/RoadshowSharePackageSampleVerify/main.py

echo "== RoadshowShareExportUI =="
python3 Scripts/RoadshowShareExportUIVerify/main.py

echo "== HomeDialogPrivacy =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/HomeDialogPrivacyMetadataFactory.swift \
  Scripts/HomeDialogPrivacyVerify/main.swift \
  -o /tmp/dreamjourney_home_dialog_privacy_verify
/tmp/dreamjourney_home_dialog_privacy_verify

echo "== FamilyAccessIdentity =="
xcrun swiftc \
  DreamJourney/Sources/Services/FamilyAccessIdentityResolver.swift \
  Scripts/FamilyAccessIdentityVerify/main.swift \
  -o /tmp/dreamjourney_family_access_identity_verify
/tmp/dreamjourney_family_access_identity_verify

echo "== FamilyAccessControl =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/FamilyAccessControlService.swift \
  Scripts/FamilyAccessControlVerify/main.swift \
  -o /tmp/dreamjourney_family_access_control_verify
/tmp/dreamjourney_family_access_control_verify

echo "== FamilyAccessControlUI =="
xcrun swift Scripts/FamilyAccessControlUIVerify/main.swift

echo "== RemoteSafetyGuard =="
xcrun swiftc \
  DreamJourney/Sources/Services/AppConfiguration.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
  Scripts/RemoteSafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_remote_safety_guard_verify
/tmp/dreamjourney_remote_safety_guard_verify

echo "== VolcEngineConfig =="
xcrun swiftc \
  DreamJourney/Sources/Services/AppConfiguration.swift \
  DreamJourney/Sources/Memoir/VolcEngineCredentialProvider.swift \
  Scripts/VolcEngineConfigVerify/main.swift \
  -o /tmp/dreamjourney_volcengine_config_verify
/tmp/dreamjourney_volcengine_config_verify

echo "== VolcEngineTTSRequest =="
xcrun swiftc \
  DreamJourney/Sources/Memoir/VolcEngineTTSRequestFactory.swift \
  Scripts/VolcEngineTTSRequestVerify/main.swift \
  -o /tmp/dreamjourney_volcengine_tts_request_verify
/tmp/dreamjourney_volcengine_tts_request_verify

echo "== VolcEngineRealtimeConfig =="
xcrun swiftc \
  DreamJourney/Sources/Services/VolcEngineRealtimeCredentialProvider.swift \
  Scripts/VolcEngineRealtimeConfigVerify/main.swift \
  -o /tmp/dreamjourney_volcengine_realtime_config_verify
/tmp/dreamjourney_volcengine_realtime_config_verify

echo "== DigitalHumanReadiness =="
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

echo "== DigitalHumanDiagnosticsUI =="
python3 Scripts/DigitalHumanDiagnosticsUIVerify/main.py

echo "== DigitalHumanRuntimeLog =="
python3 Scripts/DigitalHumanRuntimeLogVerify/main.py

echo "== FamilyFootprint =="
xcrun swiftc \
  DreamJourney/Sources/Services/MemoryModel.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintTimeline.swift \
  Scripts/FamilyFootprintVerify/main.swift \
  -o /tmp/dreamjourney_family_footprint_verify
/tmp/dreamjourney_family_footprint_verify

echo "== FamilyCircleQuickActions =="
xcrun swiftc \
  DreamJourney/Sources/Modules/Family/FamilyCircleQuickAction.swift \
  Scripts/FamilyCircleQuickActionsVerify/main.swift \
  -o /tmp/dreamjourney_family_circle_quick_actions_verify
/tmp/dreamjourney_family_circle_quick_actions_verify

echo "== FamilyFootprintIllumination typecheck =="
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun swiftc -sdk "$IOS_SDK" -target arm64-apple-ios15.0 -typecheck \
  DreamJourney/Sources/Common/UI/TGColors.swift \
  DreamJourney/Sources/Theme/UIColor+WarmTheme.swift \
  DreamJourney/Sources/Services/MemoryModel.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintTimeline.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintIllumination.swift

echo "== FamilyFootprintIlluminationPolicy =="
python3 Scripts/FamilyFootprintIlluminationPolicyVerify/main.py

echo "== FamilyFootprintPoster =="
python3 Scripts/FamilyFootprintPosterVerify/main.py

echo "== FamilyFootprintFallback =="
python3 Scripts/FamilyFootprintFallbackVerify/main.py

echo "== FamilyFootprintPoster typecheck =="
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun swiftc -sdk "$IOS_SDK" -target arm64-apple-ios15.0 -typecheck \
  DreamJourney/Sources/Common/UI/TGColors.swift \
  DreamJourney/Sources/Theme/UIColor+WarmTheme.swift \
  DreamJourney/Sources/Common/UI/TGToast.swift \
  DreamJourney/Sources/Common/Extensions/UIViewController+Extensions.swift \
  DreamJourney/Sources/Services/MemoryModel.swift \
  DreamJourney/Sources/Services/AppConfiguration.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintTimeline.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintIllumination.swift \
  DreamJourney/Sources/Modules/Map/AmapDistrictBoundaryProvider.swift \
  DreamJourney/Sources/Modules/Map/FamilyFootprintSharePoster.swift

echo "== MockDialogEngine simulator typecheck =="
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -sdk "$SIM_SDK" -target arm64-apple-ios15.0-simulator -D MOCK_DIALOG_VERIFY -typecheck \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/DialogEngineModels.swift \
  DreamJourney/Sources/Services/DialogEngineProtocol.swift \
  DreamJourney/Sources/Services/MockDialogEngine.swift \
  DreamJourney/Sources/Services/DialogEngineFactory.swift \
  Scripts/MockDialogEngineVerify/main.swift

echo "== phase2 diff --check =="
git diff --check
git diff --cached --check
