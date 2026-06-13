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
let repositoryURL = root
    .appendingPathComponent("DreamJourney")
    .appendingPathComponent("Sources")
    .appendingPathComponent("Services")
    .appendingPathComponent("FamilyRepository.swift")

let repositorySource = try String(contentsOf: repositoryURL, encoding: .utf8)

require(source.contains("接受邀请"), "family page should expose accept invitation copy")
require(source.contains("撤回访问"), "family member actions should expose revoke access copy")
require(
    source.contains("acceptBackendInvitation(phone:")
        && source.contains("acceptBackendInvitationCode("),
    "accept invitation UI should delegate phone/code acceptance to FamilyRepository"
)
require(
    repositorySource.contains("FamilyAccessControlService.acceptInvitation"),
    "FamilyRepository should apply FamilyAccessControlService.acceptInvitation when accepting local invitations"
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
