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
let backendTests = read("tests/test_core_services.py", in: backendRoot)
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let voiceShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")

for required in [
    "VOICE_CLONE_QUALITY_PREVIEW_PURPOSE = \"qualityPreview\"",
    "VOICE_CLONE_QUALITY_PREVIEW_RECEIPT_TTL_SECONDS",
    "def _voice_clone_quality_preview_receipt_hash",
    "def _issue_voice_profile_quality_preview_receipt",
    "allow_quality_preview: bool = False",
    "voice profile quality preview receipt is required",
    "requestPurpose",
    "qualityPreviewReceiptId",
    "qualityPreviewExpiresAt",
    "qualityAcceptanceReceiptHash",
    "qualityPreviewReceiptHash",
] {
    assertContains(backendMain, required, "backend must bind quality acceptance to a preview receipt \(required)")
}

assertContains(
    backendTests,
    "test_voice_clone_quality_preview_receipt_is_required_before_echo_synthesis",
    "backend tests must cover preview receipt admission"
)

for required in [
    "let qualityPreviewReceiptId: String?",
    "let qualityPreviewExpiresAt: String?",
    "previewReceiptId: String",
    "requestPurpose: String? = nil",
    "payload[\"requestPurpose\"] = requestPurpose",
] {
    assertContains(backendClient, required, "iOS backend client must carry the preview receipt contract \(required)")
}

for required in [
    "func acceptVoiceProfileQualityRemote(",
    "previewReceiptId: String",
    "previewReceiptId: trimmedPreviewReceiptId",
] {
    assertContains(voiceService, required, "voice service must forward the preview receipt \(required)")
}

for required in [
    "private struct QualityPreviewReceipt",
    "private var qualityPreviewReceipt: QualityPreviewReceipt?",
    "requestPurpose: \"qualityPreview\"",
    "qualityPreviewReceiptId",
    "currentQualityPreviewReceipt",
    "qualityPreviewReceipt: receipt",
    "previewReceiptId: receipt.value",
    "guard previewPlayer?.play() == true",
] {
    assertContains(voiceShell, required, "voice clone UI must require an actual preview playback before acceptance \(required)")
}

print("Voice clone quality preview receipt contract check passed")
