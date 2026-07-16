import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

func functionBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "func \(name)")?.lowerBound else {
        fatalError("Unable to find function \(name)")
    }
    let tail = source[start...]
    guard let nextFunction = tail.dropFirst().range(of: "\n    private func ")?.lowerBound
        ?? tail.dropFirst().range(of: "\n    @objc private func ")?.lowerBound
        ?? tail.dropFirst().range(of: "\n}")?.lowerBound else {
        return String(tail)
    }
    return String(source[start..<nextFunction])
}

let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

assertContains(careModels, "struct ProfileCareEscalationDraft", "care escalation should be a structured draft model")
assertContains(careModels, "let personaDisplayName: String", "draft should preserve selected persona display name")
assertContains(careModels, "let riskSummary: String", "draft should preserve care risk summary")
assertContains(careModels, "let nonEmergencyNotice: String", "draft should explicitly carry non-emergency boundary")
assertContains(careModels, "let medicalBoundary: String", "draft should explicitly carry non-diagnostic boundary")
assertContains(careModels, "let contractState: String", "draft should state real contact contract status")
assertContains(careModels, "static func make(snapshot: ProfileCareSnapshot, personaDisplayName: String)", "draft should be built from care snapshot and selected persona display name")
assertContains(careModels, "var alertMessage: String", "draft should render a safe hidden-alert message")
assertContains(careModels, "backendCandidatePayload(viewerUserId:", "draft should expose a backend candidate payload")
assertContains(careModels, "\"deliveryState\": \"draftOnly\"", "backend candidate payload should remain draft-only")
assertContains(careModels, "\"backendContractConnected\": false", "backend candidate payload should state backend contact is disconnected")
assertContains(careModels, "\"willContactThirdParty\": false", "backend candidate payload must not contact third parties")
assertContains(careModels, "\"containsRawTranscript\": false", "backend candidate payload must not contain raw transcript")

let doctorBody = functionBody(named: "showDoctorContactSafetyNotice()", in: profile)
let doctorContractSource = doctorBody + careModels
assertContains(doctorBody, "ProfileCareEscalationDraft.make", "doctor hidden action should create a structured escalation draft")
assertContains(doctorBody, "personaDisplayName: personaContext.displayName", "doctor hidden action should scope draft to selected persona")
assertContains(doctorBody, "draft.alertMessage", "doctor hidden action should render draft message")
assertContains(doctorBody, "关怀联系暂未接入", "doctor hidden action should keep explicit title")
assertContains(doctorContractSource, "关怀升级草稿", "doctor hidden action should expose draft wording instead of real contact")
assertContains(doctorContractSource, "非紧急", "doctor hidden action should keep non-emergency copy")
assertContains(doctorContractSource, "不是医疗诊断", "doctor hidden action should keep medical boundary")
assertContains(doctorContractSource, "真实联系契约未接入", "doctor hidden action should state contract is not connected")
assertNotContains(doctorBody, "tel://", "doctor hidden action must not launch a phone call")
assertNotContains(doctorBody, "DreamJourneyBackendClient", "doctor hidden action must not call backend contact")

assertContains(profile, "card.isAccessibilityElement = !isCareDoctorContactVisible", "hidden doctor button should remain accessible in UI smoke")
assertContains(profile, "callButton.accessibilityIdentifier = \"profileDoctorContactButton\"", "doctor contact button should have stable UIQA identifier")
assertContains(profile, "callButton.accessibilityLabel = \"生成关怀升级草稿\"", "doctor contact button should describe hidden draft action")

assertContains(releaseMatrix, "| `careDoctorContact` | hidden |", "release matrix should document the hidden care escalation boundary")
assertContains(releaseMatrix, "clinical/legal approval", "release matrix should preserve the care escalation promotion gate")

print("Profile care escalation contract checks passed")
