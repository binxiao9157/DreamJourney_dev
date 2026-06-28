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
        fatalError(message)
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError(message)
    }
}

func assertFileExists(_ relativePath: String, _ message: String) {
    let url = rootURL.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fatalError(message)
    }
}

let plist = read("DreamJourney/Resources/Info.plist")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let gitignore = read(".gitignore")

assertContains(
    plist,
    "<string>$(DREAMJOURNEY_BACKEND_BASE_URL)</string>",
    "Info.plist should resolve backend base URL from a build setting"
)
assertContains(
    plist,
    "<string>$(DREAMJOURNEY_BACKEND_API_TOKEN)</string>",
    "Info.plist should resolve backend API token from a build setting"
)
assertNotContains(
    plist,
    "<string>http://127.0.0.1:3100</string>",
    "Info.plist should not hard-code backend base URL"
)
assertNotContains(
    plist,
    "<string>YOUR_DREAMJOURNEY_BACKEND_API_TOKEN</string>",
    "Info.plist should not hard-code backend API token placeholder"
)

assertContains(
    project,
    "DREAMJOURNEY_BACKEND_BASE_URL = \"http://127.0.0.1:3100\";",
    "Xcode target should define a local default backend base URL build setting"
)
assertContains(
    project,
    "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN;",
    "Xcode target should define a placeholder backend token build setting"
)

assertContains(
    client,
    "$(DREAMJOURNEY_BACKEND_API_TOKEN)",
    "Backend client should ignore an unexpanded backend token build setting"
)
assertContains(
    client,
    "$(DREAMJOURNEY_BACKEND_BASE_URL)",
    "Backend client should ignore an unexpanded backend base URL build setting"
)

assertFileExists(
    "DreamJourney/Config/Backend.example.xcconfig",
    "Backend example xcconfig should exist"
)
let example = read("DreamJourney/Config/Backend.example.xcconfig")
assertContains(
    example,
    "DREAMJOURNEY_BACKEND_BASE_URL = http://127.0.0.1:3100",
    "Backend example xcconfig should document local base URL"
)
assertContains(
    example,
    "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN",
    "Backend example xcconfig should keep only a placeholder token"
)
assertContains(
    gitignore,
    "DreamJourney/Config/Backend.local.xcconfig",
    "Local backend xcconfig should be ignored"
)

print("Backend build config checks passed")
