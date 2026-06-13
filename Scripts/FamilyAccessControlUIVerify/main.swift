import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FamilyAccessControlUI verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let familyViewURL = root
    .appendingPathComponent("DreamJourney")
    .appendingPathComponent("Sources")
    .appendingPathComponent("Modules")
    .appendingPathComponent("Family")
    .appendingPathComponent("FamilyCircleViewController.swift")

let source = try String(contentsOf: familyViewURL, encoding: .utf8)

require(source.contains("接受邀请"), "family page should expose accept invitation copy")
require(source.contains("撤回访问"), "family member actions should expose revoke access copy")
require(
    source.contains("FamilyAccessControlService.acceptInvitation"),
    "accept invitation UI should call FamilyAccessControlService.acceptInvitation"
)
require(
    source.contains("FamilyAccessControlService.revokeMemberAccess"),
    "revoke access UI should call FamilyAccessControlService.revokeMemberAccess"
)
require(
    source.contains("trailingSwipeActionsConfigurationForRowAt")
        || source.contains("contextMenuConfigurationForRowAt"),
    "member rows should expose an explicit revoke access action"
)

print("FamilyAccessControlUI verification passed")
