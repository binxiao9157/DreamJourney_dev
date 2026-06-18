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
let profileSettings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

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

assertContains(profileSettings, "名称", "Profile settings should expose name field")
assertContains(profileSettings, "性别", "Profile settings should expose gender field")
assertContains(profileSettings, "地区", "Profile settings should expose region field")
assertContains(profileSettings, "手机号", "Profile settings should keep phone visible")
assertContains(profileSettings, "profile-settings-name-field", "Name field should be stable for QA")
assertContains(profileSettings, "profile-settings-gender-field", "Gender field should be stable for QA")
assertContains(profileSettings, "profile-settings-region-field", "Region field should be stable for QA")
assertContains(profileSettings, "profile-settings-phone-value", "Phone readonly field should be stable for QA")
assertContains(profileSettings, "名称不能为空", "Profile settings should validate name")
assertContains(profileSettings, "名称不能超过24个字", "Profile settings should cap name length")
assertContains(profileSettings, "性别仅支持：男、女、不便透露", "Profile settings should validate gender")
assertContains(profileSettings, "地区不能超过32个字", "Profile settings should cap region length")
assertContains(profileSettings, "maxRegionLength = 32", "Profile settings should keep region limit centralized")
assertContains(profileSettings, "UserManager.shared.saveProfile(nickname: name, gender: gender, region: region)", "Settings should save account fields through UserManager")
assertContains(profileSettings, "phoneValueLabel.isUserInteractionEnabled = false", "Phone number should remain readonly")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/profile-account-fields-check.swift", "release QA package should include account fields guard")
assertContains(releaseRegression, "profile-account-fields-check.swift", "release regression should run account fields guard")

print("Profile account fields checks passed")
