import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, in baseURL: URL = root) -> String {
    let fileURL = baseURL.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let backendMain = read("app/main.py", in: backendRoot)
let backendConfig = read("app/core/config.py", in: backendRoot)
let backendRuntime = read("app/services/runtime_config.py", in: backendRoot)
let backendProvider = read("app/services/voice_clone.py", in: backendRoot)
let backendTTS = read("app/services/tts.py", in: backendRoot)
let backendLifecycle = read("app/services/voice_profile_lifecycle.py", in: backendRoot)
let backendMemoryStore = read("app/services/in_memory_store.py", in: backendRoot)
let backendPostgresStore = read("app/services/postgres_store.py", in: backendRoot)
let backendBaselineMigration = read("db/migrations/0001_existing_schema_baseline.sql", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)
let backendPostgresTests = read("tests/test_postgres_store.py", in: backendRoot)
let backendReadme = read("README.md", in: backendRoot)
let backendKeySeparationDoc = read("docs/backend/2026-06-20-volcengine-voice-clone-key-separation.md", in: backendRoot)

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let memoirTTSService = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let shellGuard = read("Scripts/QA/prd-stitch-ui/voice-clone-shell-contract-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

for required in [
    "@app.post(\"/voice/profiles\")",
    "@app.get(\"/voice/profiles/{user_id}\")",
    "@app.post(\"/voice/profiles/{user_id}/{voice_profile_id}/disable\")",
    "@app.post(\"/voice/profiles/{user_id}/{voice_profile_id}/refresh\")",
    "@app.post(\"/voice/profiles/{user_id}/{voice_profile_id}/quality-acceptance\")",
    "@app.delete(\"/voice/profiles/{user_id}/{voice_profile_id}\")",
    "@app.post(\"/voice/synthesis\")",
    "_sanitize_voice_profile_payload",
    "VoiceCloneProviderFactory(settings).make()",
    "VoiceCloneTTSProviderFactory(settings).make()",
    "authorizationConfirmed",
    "voiceProfileId",
    "sampleStatus",
    "purpose",
    "consentVersion",
    "disableContract",
    "deleteContract",
] {
    assertContains(backendMain, required, "backend should expose voice clone profile contract \(required)")
}

for required in [
    "VOICE_PROFILE_LIFECYCLE_SCHEMA_VERSION = \"voice-profile-lifecycle-v1\"",
    "class VoiceProfileLifecycleState",
    "PREVIEW_READY = \"previewReady\"",
    "ACCEPTED = \"accepted\"",
    "profile_public_projection",
    "subjectEligibilityDecision",
    "allowedOperations",
    "is_voice_profile_synthesizable",
] {
    assertContains(backendLifecycle, required, "backend lifecycle module should define P1-S1 contract \(required)")
}

for required in [
    "volcengine_voice_clone_api_key",
    "VOLCENGINE_VOICE_CLONE_API_KEY",
    "VOLCENGINE_VOICE_CLONE_TRAIN_URL",
    "VOLCENGINE_VOICE_CLONE_QUERY_URL",
    "VOLCENGINE_VOICE_CLONE_SPEAKER_ID_MODE",
    "VOLCENGINE_VOICE_CLONE_SPEAKER_ID",
    "VOLCENGINE_VOICE_CLONE_TTS_API_KEY",
    "VOLCENGINE_VOICE_CLONE_TTS_URL",
    "VOLCENGINE_VOICE_CLONE_TTS_CLUSTER",
    "https://openspeech.bytedance.com/api/v3/tts/voice_clone",
    "https://openspeech.bytedance.com/api/v3/tts/get_voice",
    "https://openspeech.bytedance.com/api/v1/tts",
] {
    assertContains(backendConfig, required, "backend config should expose current voice clone env \(required)")
}

for required in [
    "VolcEngineVoiceCloneV3Provider",
    "settings.volcengine_voice_clone_train_url",
    "settings.volcengine_voice_clone_query_url",
    "X-Api-Key",
    "X-Api-Request-Id",
    "\"speaker_id\": \"custom_speaker_id\"",
    "\"custom_speaker_id\": voice_profile_id",
    "volcengine_voice_clone_speaker_id_mode",
    "VOLCENGINE_VOICE_CLONE_SPEAKER_ID",
    "build_training_request",
    "build_query_request",
] {
    assertContains(backendProvider, required, "backend provider should proxy VolcEngine V3 \(required)")
}
assertNotContains(backendProvider, "X-Api-Resource-Id", "voice clone training/query should not send deprecated resource header")

for required in [
    "VolcVoiceCloneTTSProxy",
    "settings.volcengine_voice_clone_tts_api_key",
    "settings.volcengine_voice_clone_tts_url",
    "settings.volcengine_voice_clone_tts_cluster",
    "\"x-api-key\": api_key",
    "\"voice_type\": voice_profile_id",
    "build_synthesis_request",
    "parse_tts_response",
    "parse_chunked_audio_response",
    "parse_viseme_timeline",
] {
    assertContains(backendTTS, required, "backend TTS should proxy cloned voice synthesis \(required)")
}
assertNotContains(backendTTS, "X-Api-Resource-Id", "voice clone TTS should not send deprecated resource header")

for required in [
    "\"voiceClone\"",
    "\"provider\": voice_clone_provider.provider_mode",
    "\"trainEndpoint\": \"/voice/profiles\"",
    "\"queryEndpoint\": \"/voice/profiles/{user_id}/{voice_profile_id}/refresh\"",
    "\"synthesisEndpoint\": \"/voice/synthesis\"",
] {
    assertContains(backendRuntime, required, "runtime config should expose voice clone capability \(required)")
}

for required in [
    "save_voice_profile",
    "list_voice_profiles",
    "get_voice_profile",
] {
    assertContains(backendMemoryStore, required, "memory store should persist voice profile \(required)")
    assertContains(backendPostgresStore, required, "postgres store should persist voice profile \(required)")
}

for required in [
    "CREATE TABLE voice_profiles",
    "idx_voice_profiles_user_updated",
] {
    assertContains(backendBaselineMigration, required, "versioned postgres schema should include \(required)")
}

for forbidden in [
    "rawSampleURL",
    "sampleLocalPath",
    "audioBase64",
] {
    assertContains(backendTests, "assertNotIn(\"\(forbidden)\"", "backend tests should reject raw sample field \(forbidden)")
}

for required in [
    "VoiceCloneProfileAPITests",
    "test_voice_clone_profile_contract_requires_authorization_and_persists_lifecycle",
    "test_voice_clone_profile_persists_provider_failure_code_without_raw_message",
] {
    assertContains(backendTests, required, "backend tests should cover voice clone API \(required)")
}

assertContains(
    backendPostgresTests,
    "test_store_persists_voice_profiles_disable_and_delete_states",
    "postgres tests should cover voice profile lifecycle persistence"
)

for required in [
    "struct VoiceCloneProfileContract",
    "let voiceProfileId: String",
    "let sampleStatus: VoiceCloneSampleStatus",
    "let providerStatus: String",
    "let providerMessage: String",
    "let authorizationConfirmed: Bool",
    "let disableContract: String",
    "let deleteContract: String",
    "enum VoiceProfileLifecycleState",
    "struct VoiceCloneProfileConsentContract",
    "struct VoiceCloneProfileEligibilityContract",
    "let lifecycleState: VoiceProfileLifecycleState?",
    "let allowedOperations: Set<String>",
    "var isReadyForEcho: Bool",
    "saveVoiceCloneProfile(",
    "fetchVoiceCloneProfiles(",
    "refreshVoiceCloneProfile(",
    "requestVoiceCloneSynthesis(",
    "acceptVoiceCloneQuality(",
    "disableVoiceCloneProfile(",
    "deleteVoiceCloneProfile(",
] {
    assertContains(backendClient, required, "iOS backend client should expose voice clone contract \(required)")
}

for required in [
    "backendContractEndpoint",
    "/voice/profiles",
    "DreamJourneyBackendClient.shared.saveVoiceCloneProfile",
    "DreamJourneyBackendClient.shared.refreshVoiceCloneProfile",
    "DreamJourneyBackendClient.shared.acceptVoiceCloneQuality",
] {
    assertContains(voiceService, required, "voice clone shell service should document backend contract \(required)")
}

for forbidden in [
    "https://openspeech.bytedance.com/api/v3/tts/voice_clone",
    "https://openspeech.bytedance.com/api/v3/tts/get_voice",
] {
    assertNotContains(voiceService, forbidden, "iOS VoiceCloneService must not call VolcEngine directly \(forbidden)")
}
assertNotContains(voiceService, "\"X-Api-Key\":", "iOS VoiceCloneService must not send VolcEngine API headers directly")

for required in [
    "voiceCloneSynthesisClient: VoiceCloneSynthesisClientPort = DreamJourneyBackendClient.shared",
    "voiceCloneSynthesisClient.requestVoiceCloneSynthesis",
    "synthesis.audioData",
] {
    assertContains(memoirTTSService, required, "MemoirTTSService should use backend synthesis \(required)")
}

for forbidden in [
    "VoiceCloneAPIKey",
    "https://openspeech.bytedance.com/api/v3/tts/unidirectional",
    "X-Api-Key",
] {
    assertNotContains(memoirTTSService, forbidden, "MemoirTTSService must not call VolcEngine directly \(forbidden)")
}

assertContains(backendReadme, "POST /voice/profiles", "backend README should list voice profile endpoint")
assertContains(backendReadme, "POST /voice/synthesis", "backend README should list voice synthesis endpoint")
assertContains(backendKeySeparationDoc, "VOLCENGINE_VOICE_CLONE_TTS_API_KEY", "backend docs should document dedicated synthesis key")
assertContains(backendKeySeparationDoc, "不要在当前链路里给声音复刻训练、查询或 `/api/v1/tts` 合成请求强行追加 `X-Api-Resource-Id`", "backend docs should forbid deprecated resource header")
assertContains(releaseRegression, "voice-clone-backend-contract-check.swift", "release regression should run voice clone backend guard")
assertContains(releaseQA, "voice-clone-backend-contract-check.swift", "release QA package should include voice clone backend guard")
assertContains(shellGuard, "voice-clone-backend-contract-check.swift", "voice shell guard should point to backend contract guard")
assertContains(releaseMatrix, "| `voiceCloneShell` | hidden |", "release matrix should document the V4 voice-clone boundary")
assertContains(releaseMatrix, "consent/provider approval", "release matrix should preserve the voice-clone promotion gate")

print("Voice clone backend contract guard passed")
