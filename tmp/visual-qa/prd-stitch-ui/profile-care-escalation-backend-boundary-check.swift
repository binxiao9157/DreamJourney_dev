import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
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

let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let script = read("tmp/visual-qa/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh")
let contractCheck = read("tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-check.swift")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let status = read("docs/superpowers/status/2026-06-18-profile-care-escalation-contract.md")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

assertContains(careModels, "func backendCandidatePayload(viewerUserId: String, personaOwnerId: String) -> [String: Any]", "care escalation draft should expose a backend candidate payload")
assertContains(careModels, "\"schemaVersion\": \"profileCareEscalationDraft.v1\"", "payload should pin schema version")
assertContains(careModels, "\"deliveryState\": \"draftOnly\"", "payload should stay draft-only")
assertContains(careModels, "\"requiresHumanReview\": true", "payload should require human review")
assertContains(careModels, "\"backendContractConnected\": false", "payload should state backend contact contract is not connected")
assertContains(careModels, "\"willContactThirdParty\": false", "payload should not contact third parties")
assertContains(careModels, "\"allowsEmergencyUse\": false", "payload should not claim emergency use")
assertContains(careModels, "\"containsRawTranscript\": false", "payload should not contain raw chat transcript")
assertContains(careModels, "\"personaDisplayName\": personaDisplayName", "payload should carry selected persona display name")
assertContains(careModels, "\"riskSummary\": riskSummary", "payload should carry aggregate risk summary")
assertContains(careModels, "\"viewerUserId\": viewerUserId", "payload should carry viewer id for future backend contract")
assertContains(careModels, "\"personaOwnerId\": personaOwnerId", "payload should carry persona owner id for future backend contract")

assertContains(profile, "ProfileCareEscalationDraft.make", "hidden doctor action should still create a local draft")
assertContains(profile, "sendAction.isEnabled = false", "hidden doctor action must keep submission disabled")
assertNotContains(profile, "DreamJourneyBackendClient.shared.submitCareEscalation", "hidden doctor action must not submit escalation")
assertNotContains(profile, "tel://", "hidden doctor action must not dial")

assertContains(appDelegate, "DJRunProfileCareEscalationBoundarySmoke", "UIQA should expose care escalation boundary smoke launch argument")
assertContains(appDelegate, "runProfileCareEscalationBoundarySmoke()", "AppDelegate should run care escalation boundary smoke")
assertContains(appDelegate, "writeProfileCareEscalationBoundarySmokeResult", "care escalation boundary smoke should write pollable JSON")
assertContains(appDelegate, "profile-care-escalation-boundary-smoke-result.json", "care escalation boundary smoke result filename")
assertContains(appDelegate, "backendCandidatePayload(viewerUserId:", "smoke should exercise the backend candidate payload")
assertContains(appDelegate, "selectProfileTabForCareEscalationSmoke", "smoke should select profile tab before screenshot evidence")
assertContains(appDelegate, "\"profileTabSelected\": profileTabSelected", "smoke result should record profile tab evidence")
assertContains(appDelegate, "\"willContactThirdParty\"", "smoke result should expose third-party contact boundary")
assertContains(appDelegate, "\"containsRawTranscript\"", "smoke result should expose raw transcript boundary")

assertContains(script, "DJRunProfileCareEscalationBoundarySmoke", "script should launch care escalation boundary smoke")
assertContains(script, "profile-care-escalation-boundary-smoke-result.json", "script should poll result JSON")
assertContains(script, "\"deliveryState\"[[:space:]]*:[[:space:]]*\"draftOnly\"", "script should validate draft-only state")
assertContains(script, "\"backendContractConnected\"[[:space:]]*:[[:space:]]*false", "script should validate backend contract stays disconnected")
assertContains(script, "\"willContactThirdParty\"[[:space:]]*:[[:space:]]*false", "script should validate no third-party contact")
assertContains(script, "\"allowsEmergencyUse\"[[:space:]]*:[[:space:]]*false", "script should validate no emergency claim")
assertContains(script, "\"containsRawTranscript\"[[:space:]]*:[[:space:]]*false", "script should validate raw transcript boundary")
assertContains(script, "\"profileTabSelected\"[[:space:]]*:[[:space:]]*true", "script should validate profile screenshot evidence")

assertContains(contractCheck, "backendCandidatePayload(viewerUserId:", "existing escalation contract guard should include backend payload boundary")
assertContains(releasePackage, "profile-care-escalation-backend-boundary-check.swift", "release package should include care escalation backend boundary guard")
assertContains(releasePackage, "run-profile-care-escalation-boundary-smoke.sh", "release package should include care escalation boundary smoke")
assertContains(status, "run-profile-care-escalation-boundary-smoke.sh", "status doc should document the care escalation boundary smoke")
assertContains(releaseMatrix, "profile-care-escalation-backend-boundary-check.swift", "release matrix should document backend boundary guard")

print("Profile care escalation backend boundary checks passed")
