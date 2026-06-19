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

let backendMain = read("app/main.py", in: backendRoot)
let backendMemoryStore = read("app/services/in_memory_store.py", in: backendRoot)
let backendPostgresStore = read("app/services/postgres_store.py", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)
let backendPostgresTests = read("tests/test_postgres_store.py", in: backendRoot)
let backendReadme = read("README.md", in: backendRoot)

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let shellGuard = read("tmp/visual-qa/prd-stitch-ui/voice-clone-shell-contract-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

for required in [
    "@app.post(\"/voice/profiles\")",
    "@app.get(\"/voice/profiles/{user_id}\")",
    "@app.post(\"/voice/profiles/{user_id}/{voice_profile_id}/disable\")",
    "@app.delete(\"/voice/profiles/{user_id}/{voice_profile_id}\")",
    "_sanitize_voice_profile_payload",
    "authorizationConfirmed",
    "voiceProfileId",
    "sampleStatus",
    "disableContract",
    "deleteContract",
] {
    assertContains(backendMain, required, "backend should expose voice clone profile contract \(required)")
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
    "CREATE TABLE IF NOT EXISTS voice_profiles",
    "idx_voice_profiles_user_updated",
] {
    assertContains(backendPostgresStore, required, "postgres schema should include \(required)")
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
    "let authorizationConfirmed: Bool",
    "let disableContract: String",
    "let deleteContract: String",
    "saveVoiceCloneProfile(",
    "fetchVoiceCloneProfiles(",
    "disableVoiceCloneProfile(",
    "deleteVoiceCloneProfile(",
] {
    assertContains(backendClient, required, "iOS backend client should expose voice clone contract \(required)")
}

for required in [
    "backendContractEndpoint",
    "/voice/profiles",
] {
    assertContains(voiceService, required, "voice clone shell service should document backend contract \(required)")
}

assertContains(backendReadme, "POST /voice/profiles", "backend README should list voice profile endpoint")
assertContains(releaseRegression, "voice-clone-backend-contract-check.swift", "release regression should run voice clone backend guard")
assertContains(releaseQA, "voice-clone-backend-contract-check.swift", "release QA package should include voice clone backend guard")
assertContains(shellGuard, "voice-clone-backend-contract-check.swift", "voice shell guard should point to backend contract guard")
assertContains(releaseMatrix, "voice-clone-backend-contract-check.swift", "release matrix should document voice clone backend guard")

print("Voice clone backend contract guard passed")
