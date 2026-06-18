import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
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

let userModel = read("DreamJourney/Sources/Services/MemoryModel.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")

assertContains(userModel, "var gender: String?", "UserModel should store gender")
assertContains(userModel, "var region: String?", "UserModel should store region")
assertContains(userModel, "var avatarName: String?", "UserModel should keep avatar display")
assertContains(userModel, "gender: String? = nil", "UserModel initializer should keep old callers source-compatible")
assertContains(userModel, "region: String? = nil", "UserModel initializer should keep old callers source-compatible")

assertContains(userManager, "saveProfile(nickname: String, gender: String?, region: String?", "UserManager should save full account profile fields")
assertContains(userManager, "user.gender = normalizedProfileField(gender)", "UserManager should persist gender")
assertContains(userManager, "user.region = normalizedProfileField(region)", "UserManager should persist region")
assertContains(userManager, "func normalizedProfileField", "UserManager should normalize optional profile fields")
assertContains(userManager, "func saveProfile(nickname: String, completion:", "Legacy nickname-only save path should stay compatible")
assertContains(userManager, "DreamJourneyBackendClient.shared.upsertUser", "Profile sync fallback should keep existing backend behavior")

print("Profile account fields checks passed")
