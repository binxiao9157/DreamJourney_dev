import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, from base: URL = root) -> String {
    let url = base.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("echo-voice-synthesis-binding-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(named name: String, in source: String) -> String {
    let privateSignature = source.range(of: "private func \(name)")
    let internalSignature = source.range(of: "func \(name)")
    guard let signature = privateSignature ?? internalSignature,
          let openBrace = source[signature.lowerBound...].firstIndex(of: "{") else {
        require(false, "\(name) is missing")
        return ""
    }

    var depth = 0
    var index = openBrace
    while index < source.endIndex {
        switch source[index] {
        case "{":
            depth += 1
        case "}":
            depth -= 1
            if depth == 0 {
                return String(source[openBrace...index])
            }
        default:
            break
        }
        index = source.index(after: index)
    }
    require(false, "\(name) body is not balanced")
    return ""
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backend = read("app/main.py", from: backendRoot)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct VoiceCloneSynthesisBinding",
    "let schemaVersion: String",
    "let ownerUserId: String",
    "let voiceProfileId: String",
    "let profileVersion: Int",
    "let textHash: String",
    "let roleSubjectId: String",
    "let roleKey: String",
    "let personaScope: String",
    "let digitalHumanId: String",
    "let requestPurpose: String",
    "let outputMode: String",
    "let audioOwner: String",
    "let synthesisBinding: VoiceCloneSynthesisBinding?",
    "VoiceCloneSynthesisBinding(json: json[\"synthesisBinding\"] as? [String: Any])",
    "func isBound(",
    "voice-synthesis-binding-v2",
    "static func textHash(for text: String)",
    "expectedProfileVersion: Int? = nil",
    "payload[\"expectedProfileVersion\"] = expectedProfileVersion",
    "roleKey: String? = nil",
    "payload[\"roleKey\"] = roleKey",
    "roleSubjectId: String? = nil",
    "payload[\"roleSubjectId\"] = roleSubjectId",
    "personaScope: String? = nil",
    "payload[\"personaScope\"] = personaScope",
    "digitalHumanId: String? = nil",
    "payload[\"digitalHumanId\"] = digitalHumanId",
    "let bindingResult: String",
    "let bindingSchemaVersion: String?",
    "self.bindingResult = synthesis.synthesisBinding == nil ? \"missing\" : \"matched\"",
] {
    require(client.contains(required), "iOS synthesis client should bind \(required)")
}

for required in [
    "role_key = str(payload.get(\"roleKey\")",
    "role_subject_id = str(payload.get(\"roleSubjectId\")",
    "synthesisBinding",
    "\"ownerUserId\": user_id",
    "\"voiceProfileId\": voice_profile_id",
    "\"roleKey\": \"personalOwner\"",
    "\"roleSubjectId\": user_id",
    "\"personaScope\": \"personal\"",
    "\"digitalHumanId\": user_id",
    "\"requestPurpose\": VOICE_CLONE_ECHO_SYNTHESIS_PURPOSE",
    "\"outputMode\": \"tencentAudioDrive\"",
    "\"audioOwner\": VOICE_SYNTHESIS_TENCENT_AUDIO_OWNER",
    "\"textHash\": hashlib.sha256(text.encode(\"utf-8\")).hexdigest()",
    "VOICE_SYNTHESIS_BINDING_SCHEMA_VERSION = \"voice-synthesis-binding-v2\"",
] {
    require(backend.contains(required), "backend synthesis response should bind \(required)")
}

let pcmDrive = functionBody(named: "sendEchoReplyViaTencentVoiceClonePCMDrive", in: echo)
for required in [
    "let roleKey = voiceSelection.source.rawValue",
    "requestPurpose: \"echo\"",
    "expectedProfileVersion: voiceCloneUseTicket.profileVersion",
    "roleKey: roleKey",
    "roleSubjectId: userId",
    "personaScope: \"personal\"",
    "digitalHumanId: userId",
    "synthesis.voiceProfileId == voiceProfileId",
    "synthesis.isBound(",
    "profileVersion: voiceCloneUseTicket.profileVersion",
    "textHash: VoiceCloneSynthesisBinding.textHash(for: normalizedText)",
    "audioOwner: \"tencentDigitalHuman\"",
    "\"synthesisBindingMismatch\"",
] {
    require(pcmDrive.contains(required), "Echo PCM route should validate \(required)")
}
require(
    !pcmDrive.contains("fallbackToTencentText(\"voiceClonePCMDriveFallbackToTencentText\")"),
    "binding mismatch must not fall back to a default Tencent voice"
)
require(
    echo.contains("handleVoiceClonePCMDriveFailureWithoutDefaultVoice"),
    "binding mismatch must finish through the explicit no-default-voice failure path"
)
require(
    releaseRegression.contains("echo-voice-synthesis-binding-check.swift"),
    "release regression should execute the synthesis binding guard"
)
require(
    releaseQA.contains("echo-voice-synthesis-binding-check.swift"),
    "release QA package should include the synthesis binding guard"
)

print("echo-voice-synthesis-binding-check passed")
