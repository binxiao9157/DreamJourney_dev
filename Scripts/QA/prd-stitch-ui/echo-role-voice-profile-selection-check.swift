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
let knowledgePolicy = read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let knowledgeManager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
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
    "case familyVoiceNotPermitted",
    "private func resolveEchoRoleVoiceProfileSelection",
    "private func isCurrentUserPersonaContext",
    "private func currentDigitalHumanRuntimeContextKey",
    "private func digitalHumanRuntimeContextKey(for context: DigitalHumanContext)",
    "private func isCurrentDigitalHumanSessionRequest",
    "private func reconcileDigitalHumanRuntimeWithCurrentContext",
    "pendingDigitalHumanSessionRequestID",
    "pendingDigitalHumanSessionContextKey",
    "digitalHumanRuntimeContextKey",
    "sessionResponseIgnored",
    "staleSessionRequestInvalidated",
    "contextChanged",
    "DigitalHumanContextStore.shared.current",
    "VoiceCloneService.shared.currentUsableSpeakerId",
    "本人暂未启用复刻音色",
    "家人复刻音色当前不可用于回响",
    "source: .familyVoiceNotPermitted",
    "\"voiceSource\": voiceSelection.source.rawValue",
    "roleVoiceSource: voiceSelection.source.rawValue",
    "roleVoiceDisplayName: voiceSelection.displayName",
    "roleVoiceContextOwnerId: voiceSelection.contextOwnerId",
    "roleVoiceSource: \\(PrivacySafeDiagnostics.safeCode(snapshot.roleVoiceSource, fallback: \"unknown\"))",
    "roleVoiceDisplayNameHash: \\(PrivacySafeDiagnostics.correlationHash(snapshot.roleVoiceDisplayName))",
    "roleVoiceContextOwnerHash: \\(PrivacySafeDiagnostics.correlationHash(snapshot.roleVoiceContextOwnerId))",
    "uiqa_family_voice_panel_member",
    "S_uiqa_family_profile_must_not_route",
    "familyVoiceProfileBlocked",
    "setEchoAudioOwner(.tencentDigitalHuman, reason: \"uiqaPanelFamilyVoiceSelection\")",
    "latestRuntimeRoleVoiceSource",
    "latestRuntimeVoiceProfileId",
    "latestRuntimeAudioOwner"
] {
    require(echo.contains(required), "Echo should resolve voice profile by active role \(required)")
}

require(knowledgePolicy.contains("enum KBPersonaIdentityResolver"), "canonical persona resolver should remain available")
require(knowledgePolicy.contains("let isPersonal = isSelfAssistant"), "personal identity should require explicit self semantics")
require(knowledgePolicy.contains("normalizedOwnerId == effectiveViewerId"), "owner/viewer exact match should retain personal semantics")
require(!knowledgePolicy.contains("[\"本人\", \"自己\", \"我\"]"), "relation text must not grant personal identity")
require(knowledgeManager.contains("resolveAuthorizedPersonaIdentity(for context: DigitalHumanContext)"), "role selection should have an authorization-aware persona resolver")
require(echo.contains("KBLiteManager.resolveAuthorizedPersonaIdentity(for: context)?.isPersonal == true"), "role voice selection must fail closed for unauthorized contexts")

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
require(voiceClonePCMDriveBody.contains("let contextKey = currentDigitalHumanRuntimeContextKey()"), "PCM-drive requests should capture active persona context")
require(voiceClonePCMDriveBody.contains("self.currentDigitalHumanRuntimeContextKey() == contextKey"), "PCM-drive responses should be dropped after persona switches")
require(!voiceClonePCMDriveBody.contains("VoiceCloneService.shared.currentUsableSpeakerId"), "PCM-drive should consume resolved role voice profile, not directly use the current user's voice clone for every role")

let roleVoiceSelectionBody = functionBody(named: "resolveEchoRoleVoiceProfileSelection", in: echo)
require(roleVoiceSelectionBody.contains("source: .familyVoiceNotPermitted"), "family roles must resolve to a default-deny voice source")
require(roleVoiceSelectionBody.contains("voiceProfileId: nil"), "family roles must clear any selected cloned voice profile")
require(!roleVoiceSelectionBody.contains("FamilyRepository.shared.acceptedMember"), "family relationship lookup must not authorize Echo voice synthesis")
require(!roleVoiceSelectionBody.contains("normalizedVoiceProfileId"), "family voice profile IDs must not enter Echo role selection")
require(
    echo.contains("case .selfAssistantDefault, .personalOwner, .familyVoiceNotPermitted:\n            return false"),
    "family voice denial should remain QA-only and not add a public missing-voice notice"
)

let startPCMDriveBody = functionBody(named: "startPCMDriveSignalToDigitalHumanRuntime", in: echo)
require(startPCMDriveBody.contains("contextKey: contextKey"), "PCM-drive chunk scheduling should carry the persona context")

let schedulePCMDriveBody = functionBody(named: "scheduleTencentDigitalHumanPCMDriveChunks", in: echo)
require(schedulePCMDriveBody.contains("self.currentDigitalHumanRuntimeContextKey() == contextKey"), "PCM-drive chunks should stop after persona switches")

let notEnabledBody = functionBody(named: "showVoiceCloneNotEnabledStatusIfNeeded", in: echo)
require(notEnabledBody.contains("let voiceSelection = resolveEchoRoleVoiceProfileSelection()"), "voice status should resolve active role")
require(notEnabledBody.contains("voiceSelection.shouldShowMissingStatus"), "AI assistant should not show missing cloned voice status")
require(notEnabledBody.contains("voiceSelection.statusText"), "personal missing voice should show a role-specific fallback status")
require(!notEnabledBody.contains("VoiceCloneService.shared.currentUsableSpeakerId"), "missing voice status must not be based on current user's voice clone")

let onErrorBody = functionBody(named: "onError", in: echo)
require(onErrorBody.contains("sanitizedDialogEngineErrorMessage"), "Echo should sanitize low-level DialogEngine errors before showing users")
require(echo.contains("private func sanitizedDialogEngineErrorMessage"), "Echo should define a dialog error sanitizer")
require(echo.contains("opus encode input audio size") && echo.contains("音频正在切换，请再说一次"), "Echo should map transient SAMI encoder errors to a user-safe retry message")

for required in [
    "latestRuntimeRoleVoiceSource",
    "latestRuntimeVoiceProfileId",
    "latestRuntimeAudioOwner",
    "familyVoiceNotPermitted",
    "familyVoiceProfileBlocked",
    "voiceProfileIdHash\" not in runtime_diagnostics",
    "tencentDigitalHuman"
] {
    require(panelSmoke.contains(required), "panel export smoke should assert role voice diagnostics \(required)")
}

require(releaseRegression.contains("echo-role-voice-profile-selection-check.swift"), "release regression should run role voice profile guard")
require(releaseQA.contains("echo-role-voice-profile-selection-check.swift"), "release QA package should include role voice profile guard")

print("echo-role-voice-profile-selection-check passed")
