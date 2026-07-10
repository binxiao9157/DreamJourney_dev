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

func assertOrder(_ haystack: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = haystack.range(of: first),
          let secondRange = haystack.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

let plist = read("DreamJourney/Resources/Info.plist")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(plist, "<key>DreamJourneyBackendAPIToken</key>", "Info.plist should define backend API token slot")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_API_TOKEN)</string>", "backend API token should resolve from a build setting")
assertContains(project, "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN;", "backend API token build setting should stay placeholder by default")

assertContains(client, "DreamJourneyBackendAPIToken", "backend client should read backend API token")
assertContains(client, "YOUR_DREAMJOURNEY_BACKEND_API_TOKEN", "backend client should ignore placeholder backend token")
assertContains(client, "$(DREAMJOURNEY_BACKEND_API_TOKEN)", "backend client should ignore unexpanded backend token build setting")
assertContains(client, "private let apiToken: String?", "backend client should keep optional token state")
assertContains(client, "private var authHeaders: HTTPHeaders?", "backend client should build optional auth headers")
assertContains(client, "Authorization", "backend client should send Authorization header when token is configured")
assertContains(client, "Bearer \\(apiToken)", "backend client should use bearer token scheme")
assertContains(client, "authHeaders(for: authPolicy)", "backend client requests should apply the selected auth policy")
assertContains(client, "X-DreamJourney-Api-Token", "backend compatibility token should use a dedicated header beside user auth")
assertOrder(client, "private let apiToken: String?", "AF.request", "token should be resolved before requests are made")

print("Backend auth token source checks passed")
