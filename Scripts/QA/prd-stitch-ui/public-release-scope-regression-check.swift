import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Missing file: \(path)")
    }
    return value
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let runner = read("Scripts/QA/prd-stitch-ui/run-public-release-scope-regression.sh")
let modelRunner = read("Scripts/QA/prd-stitch-ui/run-public-release-scope-model-smoke.sh")
let uiqaRunner = read("Scripts/QA/prd-stitch-ui/run-public-release-scope-uiqa-smoke.sh")
let evidenceBuilder = read("Scripts/QA/prd-stitch-ui/public-release-scope-evidence.py")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let installer = read("Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh")
let infoPlist = read("DreamJourney/Resources/Info.plist")
let sceneDelegate = read("DreamJourney/Sources/SceneDelegate.swift")
let appCoordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
let accountLease = read("DreamJourney/Sources/App/AccountLease.swift")

for required in [
    "run-public-release-scope-model-smoke.sh",
    "run-release-qa-override-artifact-scan.sh",
    "run-public-release-scope-uiqa-smoke.sh",
    "run-backend-public-release-scope-deployed-smoke.sh",
    "public-release-scope-evidence.py",
] {
    require(runner.contains(required), "public release runner missing \(required)")
}
require(modelRunner.contains("public-release-scope-model-smoke.swift"), "model runner must execute the typed policy fixture")
require(uiqaRunner.contains("CONFIGURATION=Release"), "G1 must use a Release simulator build")
require(uiqaRunner.contains("dreamjourney://"), "G1 must probe a hidden deep link")
require(uiqaRunner.contains("hiddenDeepLinkBypassCount"), "G1 must report deep-link bypass count")
require(uiqaRunner.contains("RELEASE_SCOPE_SIMULATOR"), "Release simulator must isolate platform stubs from QA controls")
require(evidenceBuilder.contains("policyVersion"), "evidence bundle must include the policy version")
require(evidenceBuilder.contains("commands"), "evidence bundle must include command decisions")
require(evidenceBuilder.contains("forbidden_keys"), "evidence bundle must reject secret/body fields")
require(releaseRegression.contains("RUN_PUBLIC_RELEASE_SCOPE_GATE"), "release regression must expose the combined gate")
require(releaseRegression.contains("RUN_PUBLIC_RELEASE_SCOPE_GATE=1"), "release handoff must force the combined gate")
require(installer.contains("Release builds cannot enable DEBUG or UI_QA_SIMULATOR"), "installer must reject QA conditions in Release")
require(!infoPlist.contains("CFBundleURLTypes"), "Closed Pilot must not register a custom URL scheme")
require(
    sceneDelegate.contains("func scene(_ scene: UIScene, openURLContexts")
        && sceneDelegate.contains("receiveNotificationRuntimeDeepLink(context.url)"),
    "external URL ingress must only forward to the notification runtime router"
)
require(
    appCoordinator.contains("notificationRuntimeRouteInbox.ingest(deepLinkURL: url)"),
    "deep-link ingress must be validated by NotificationRuntimeRouteInbox"
)
require(
    accountLease.contains("NotificationRuntimeRoutePayload(deepLinkURL: deepLinkURL)")
        && accountLease.contains("payload.matches(accountLease)"),
    "deep-link payloads must be account-lease scoped before routing"
)

print("Public Release Scope regression contract passed")
