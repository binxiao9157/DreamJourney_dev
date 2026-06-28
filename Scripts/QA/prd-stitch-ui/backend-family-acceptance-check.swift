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

let repository = read("DreamJourney/Sources/Services/FamilyRepository.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let script = read("Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh")
let backendSmokeCheck = read("Scripts/QA/prd-stitch-ui/backend-env-smoke-check.swift")
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let gapMap = read("docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md")

assertContains(backendClient, "func listFamilyMembers(userId:", "backend client must expose family list endpoint")

assertContains(repository, "func refreshFromBackend(userId:", "family repository must refresh accepted members from backend")
assertContains(repository, "DreamJourneyBackendClient.shared.listFamilyMembers(userId:", "family repository must use backend family list API")
assertContains(repository, "Self.familyMembers(from: object)", "family repository must parse backend family member payload")
assertContains(repository, "accessStatus", "family repository must respect backend accepted/active membership state")
assertContains(repository, "mergeRemoteMembers", "family repository must merge remote members without dropping local fallback data")
assertContains(repository, "applyModeOverride(to:", "backend family members should preserve hidden mode overrides")

assertContains(appDelegate, "FamilyRepository.shared.refreshFromBackend(userId: userId)", "backend smoke must exercise app-side family refresh")
assertContains(appDelegate, "familyRefreshSucceeded", "backend smoke result must expose family refresh success")
assertContains(appDelegate, "backendFamilyMemberCount", "backend smoke result must expose backend family member count")
assertContains(appDelegate, "containsBackendFamilyMember", "backend smoke result must assert seeded backend family member exists")
assertContains(appDelegate, "familyMemberNames", "backend smoke result must include family names for debugging")
assertContains(appDelegate, "\"Daughter\"", "backend smoke should validate the seeded backend contract family member")

assertContains(script, "\"familyRefreshSucceeded\"", "backend smoke script must validate family refresh success")
assertContains(script, "\"containsBackendFamilyMember\"", "backend smoke script must validate seeded backend family member")
assertContains(script, "\"backendFamilyMemberCount\"", "backend smoke script must validate family count")
assertContains(script, "Family member count", "backend smoke report must mention family evidence")

assertContains(backendSmokeCheck, "backend-family-acceptance-check.swift", "backend smoke static package should include family acceptance guard")
assertContains(readinessDoc, "backend-family-acceptance-check.swift", "backend readiness doc must document family acceptance guard")
assertContains(readinessDoc, "familyRefreshSucceeded", "backend readiness doc must document family app-side smoke output")
assertContains(gapMap, "backend-family-acceptance-check.swift", "gap map must list family backend acceptance verification")

print("Backend family acceptance checks passed")
