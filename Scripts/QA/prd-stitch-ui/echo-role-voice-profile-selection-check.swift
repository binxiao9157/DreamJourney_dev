import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(relativePath)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("echo-role-voice-profile-selection-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(named functionName: String, in source: String) -> String {
    let privateSignature = source.range(of: "private func \(functionName)")
    let internalSignature = source.range(of: "func \(functionName)")
    guard let signature = privateSignature ?? internalSignature else {
        require(false, "\(functionName) is missing")
        return ""
    }
    guard let openBrace = source[signature.lowerBound...].firstIndex(of: "{") else {
        require(false, "\(functionName) body is missing")
        return ""
    }

    var depth = 0
    var index = openBrace
    while index < source.endIndex {
        let character = source[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openBrace...index])
            }
        }
        index = source.index(after: index)
    }
    require(false, "\(functionName) body is not balanced")
    return ""
}

let familyModel = read("DreamJourney/Sources/Services/MemoryModel.swift")
let familyDetail = read("DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let panelSmoke = read("Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "var voiceProfileId: String?",
    "var voiceSampleStatus: String",
    "var voiceEnabled: Bool",
    "var normalizedVoiceProfileId: String?",
    "var isVoiceProfileReadyForEcho: Bool",
    "voiceProfileId = try container.decodeIfPresent(String.self, forKey: .voiceProfileId)",
    "voiceSampleStatus = try container.decodeIfPresent(String.self, forKey: .voiceSampleStatus)",
    "voiceEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceEnabled)",
    "voiceProfileId: stringValue(in: object, for: \"voiceProfileId\")",
    "voiceSampleStatus: stringValue(in: object, for: \"voiceSampleStatus\")",
    "voiceEnabled: boolValue(in: object, for: \"voiceEnabled\")"
] {
    require(familyModel.contains(required), "FamilyMember should expose family voice clone contract \(required)")
}

for required in [
    "voiceStatusLabel",
    "member.voiceCloneStatusLabel",
    "familyMemberVoiceStatus"
] {
    require(familyDetail.contains(required), "Family member detail should show voice clone status \(required)")
}

for required in [
    "EchoRoleVoiceProfileSelection",
    "case selfAssistantDefault",
    "case personalOwner",
    "case personalOwnerVoiceProfileMissing",
    "case familyMember",
    "case familyVoiceProfileMissing",
    "private func resolveEchoRoleVoiceProfileSelection",
    "private func isCurrentUserPersonaContext",
    "DigitalHumanContextStore.shared.current",
    "context.relation",
    "\"本人\"",
    "VoiceCloneService.shared.currentUsableSpeakerId",
    "本人暂未启用复刻音色",
    "FamilyRepository.shared.get(by: context.ownerId)",
    "member.isVoiceProfileReadyForEcho",
    "member.normalizedVoiceProfileId",
    "该家人暂未配置复刻音色",
    "voiceSource=\\(voiceSelection.source.rawValue)",
    "roleVoiceSource: voiceSelection.source.rawValue",
    "roleVoiceDisplayName: voiceSelection.displayName",
    "roleVoiceContextOwnerId: voiceSelection.contextOwnerId",
    "roleVoiceSource: \\(snapshot.roleVoiceSource ?? \"unknown\")",
    "roleVoiceDisplayName: \\(snapshot.roleVoiceDisplayName ?? \"unknown\")",
    "roleVoiceContextOwnerId: \\(snapshot.roleVoiceContextOwnerId ?? \"unknown\")",
    "uiqa_family_voice_panel_member",
    "S_uiqa_family_panel_voice",
    "setEchoAudioOwner(.tencentDigitalHuman, reason: \"uiqaPanelFamilyVoiceSelection\")",
    "latestRuntimeRoleVoiceSource",
    "latestRuntimeVoiceProfileId",
    "latestRuntimeAudioOwner"
] {
    require(echo.contains(required), "Echo should resolve voice profile by active role \(required)")
}

for required in [
    "let roleVoiceSource: String?",
    "let roleVoiceDisplayName: String?",
    "let roleVoiceContextOwnerId: String?",
    "roleVoiceSource: String? = nil",
    "roleVoiceDisplayName: String? = nil",
    "roleVoiceContextOwnerId: String? = nil",
    "self.roleVoiceSource = roleVoiceSource",
    "self.roleVoiceDisplayName = roleVoiceDisplayName",
    "self.roleVoiceContextOwnerId = roleVoiceContextOwnerId"
] {
    require(backendClient.contains(required), "runtime diagnostics should include role voice selection \(required)")
}

let voiceClonePCMDriveBody = functionBody(named: "sendEchoReplyViaTencentVoiceClonePCMDrive", in: echo)
require(voiceClonePCMDriveBody.contains("let voiceSelection = resolveEchoRoleVoiceProfileSelection()"), "PCM-drive should resolve voice profile from current Echo role")
require(voiceClonePCMDriveBody.contains("let voiceProfileId = voiceSelection.voiceProfileId"), "PCM-drive should use selected role voiceProfileId")
require(!voiceClonePCMDriveBody.contains("VoiceCloneService.shared.currentUsableSpeakerId"), "PCM-drive should consume resolved role voice profile, not directly use the current user's voice clone for every role")

let notEnabledBody = functionBody(named: "showVoiceCloneNotEnabledStatusIfNeeded", in: echo)
require(notEnabledBody.contains("let voiceSelection = resolveEchoRoleVoiceProfileSelection()"), "voice status should resolve active role")
require(notEnabledBody.contains("voiceSelection.shouldShowMissingStatus"), "AI assistant should not show missing cloned voice status")
require(notEnabledBody.contains("voiceSelection.statusText"), "family missing voice should show role-specific status")
require(!notEnabledBody.contains("VoiceCloneService.shared.currentUsableSpeakerId"), "missing voice status must not be based on current user's voice clone")

let onErrorBody = functionBody(named: "onError", in: echo)
require(onErrorBody.contains("sanitizedDialogEngineErrorMessage"), "Echo should sanitize low-level DialogEngine errors before showing users")
require(echo.contains("private func sanitizedDialogEngineErrorMessage"), "Echo should define a dialog error sanitizer")
require(echo.contains("opus encode input audio size") && echo.contains("音频正在切换，请再说一次"), "Echo should map transient SAMI encoder errors to a user-safe retry message")

for required in [
    "latestRuntimeRoleVoiceSource",
    "latestRuntimeVoiceProfileId",
    "latestRuntimeAudioOwner",
    "familyMember",
    "S_uiqa_family_panel_voice",
    "tencentDigitalHuman"
] {
    require(panelSmoke.contains(required), "panel export smoke should assert role voice diagnostics \(required)")
}

require(releaseRegression.contains("echo-role-voice-profile-selection-check.swift"), "release regression should run role voice profile guard")
require(releaseQA.contains("echo-role-voice-profile-selection-check.swift"), "release QA package should include role voice profile guard")

print("echo-role-voice-profile-selection-check passed")
