import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let plist = read("DreamJourney/Resources/Info.plist")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

for retired in ["DreamJourneyBackendAPIToken", "DREAMJOURNEY_BACKEND_API_TOKEN", "X-DreamJourney-Api-Token"] {
    require(!plist.contains(retired), "Info.plist must not package retired shared credential \(retired)")
    require(!project.contains(retired), "Xcode project must not define retired shared credential \(retired)")
    require(!client.contains(retired), "Backend client must not read or send retired shared credential \(retired)")
}

for required in [
    "case publicRequest",
    "case userRequired",
    "case refreshExchange",
    "case userAuthenticationRequired",
    "authPolicy: RequestAuthPolicy",
    "guard let authenticatedSession = currentSession else",
    "\"Authorization\": \"Bearer \\(session.accessToken)\"",
] {
    require(client.contains(required), "Explicit user-session auth contract is missing: \(required)")
}
require(!client.contains("authPolicy: RequestAuthPolicy ="), "Requests must not inherit an implicit auth policy")

print("Backend user-session auth boundary checks passed")
