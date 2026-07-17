import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Missing required file: \(path)\n", stderr)
        exit(1)
    }
    return value
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Knowledge Widget privacy lifecycle check failed: \(message)\n", stderr)
        exit(1)
    }
}

func contains(_ source: String, _ value: String, _ message: String) {
    require(source.contains(value), message)
}

func excludes(_ source: String, _ value: String, _ message: String) {
    require(!source.contains(value), message)
}

let models = read("DreamJourney/Sources/Services/KBLiteModels.swift")
let policy = read("DreamJourney/Sources/Services/KnowledgeWidgetPrivacyPolicy.swift")
let store = read("DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift")
let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
let widgetModels = read("DreamJourneyWidget/SharedModels.swift")
let widgetReader = read("DreamJourneyWidget/WidgetKnowledgeSnapshotReader.swift")
let widgetProvider = read("DreamJourneyWidget/TodayInHistoryProvider.swift")
let widgetEntry = read("DreamJourneyWidget/TodayInHistoryEntry.swift")
let widgetView = read("DreamJourneyWidget/TodayInHistoryView.swift")
let appEntitlements = read("DreamJourney/DreamJourney.entitlements")
let widgetEntitlements = read("DreamJourneyWidget/DreamJourneyWidget.entitlements")
let appInfo = read("DreamJourney/Resources/Info.plist")
let widgetInfo = read("DreamJourneyWidget/Info.plist")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

contains(models, "var widgetVisibility: String? = nil", "legacy metadata must default Widget visibility to deny")
contains(policy, "event.privacyMetadata?.scope == \"generationAllowed\"", "policy must require generation permission")
contains(policy, "event.privacyMetadata?.widgetVisibility == summaryAllowed", "policy must require explicit Widget permission")
contains(policy, "event.ownerUserId == normalizedOwner", "policy must bind the current owner")
contains(policy, "event.personaScope == \"personal\"", "family persona must not enter Widget")
contains(policy, "event.evidenceStatus == \"confirmed\"", "only confirmed evidence may enter Widget")
excludes(policy, "description:", "snapshot schema must not include event descriptions")
excludes(policy, "sourceRefs", "snapshot schema must not include source references")

contains(store, "activeOwnerDigestKey", "store must publish active owner identity")
contains(store, "generation == activeGeneration", "store must reject stale generations")
contains(store, "AccountLeaseRuntimePort", "store must consume the central AccountLease runtime")
contains(store, "at: .commit", "snapshot file publication must validate the account lease")
contains(store, "at: .runtime", "Widget timeline reload must validate the account lease")
contains(store, "reloadTimelines(ofKind:", "store must invalidate Widget timeline")
contains(store, "completeUntilFirstUserAuthentication", "snapshot must define file protection")
contains(manager, "widgetSnapshotStore.activate", "account lifecycle must activate or revoke Widget identity")
contains(manager, "let generation = userGeneration", "save must capture publication generation")
contains(manager, "widgetSnapshotStore.publish", "KBLite save/switch must use the guarded store")
excludes(manager, "writeToAppGroup", "legacy unguarded App Group exporter must be removed")
excludes(manager, "kb_widget_data.json", "legacy Widget file must not be written")

contains(widgetModels, "schemaVersion", "Widget snapshot must be versioned")
contains(widgetModels, "ownerDigest", "Widget snapshot must carry owner digest")
excludes(widgetModels, "description", "Widget shared schema must not carry descriptions")
contains(widgetReader, "snapshot.ownerDigest == activeOwnerDigest", "Widget reader must enforce current identity")
contains(widgetReader, "snapshot.schemaVersion == currentSchemaVersion", "Widget reader must enforce schema")
contains(widgetProvider, "WidgetKnowledgeSnapshotReader.acceptedEvents", "provider must use fail-closed reader")
excludes(widgetEntry, "description", "timeline entry must not retain descriptions")
contains(widgetView, ".privacySensitive()", "displayed knowledge summaries must use system privacy treatment")

for entitlements in [appEntitlements, widgetEntitlements] {
    contains(entitlements, "com.apple.security.application-groups", "both targets must declare App Group entitlement")
    contains(entitlements, "$(DREAMJOURNEY_APP_GROUP_IDENTIFIER)", "both targets must use the configurable App Group")
}
for info in [appInfo, widgetInfo] {
    contains(info, "DreamJourneyAppGroupIdentifier", "both bundles must expose the App Group identifier")
}
contains(project, "Embed App Extensions", "main target must embed the Widget extension")
contains(project, "PBXTargetDependency", "main target must depend on Widget target")
contains(project, "$(DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER).widget", "Widget bundle ID must derive from the app")
contains(project, "DreamJourneyWidget/DreamJourneyWidget.entitlements", "Widget target must use its entitlement file")
contains(project, "KnowledgeWidgetPrivacyPolicy.swift in Sources", "privacy policy must belong to app target")
contains(project, "KnowledgeWidgetSnapshotStore.swift in Sources", "snapshot store must belong to app target")
contains(project, "WidgetKnowledgeSnapshotReader.swift in Sources", "reader must belong to Widget target")

for runner in [
    "run-knowledge-widget-privacy-policy-model-smoke.sh",
    "run-knowledge-widget-snapshot-store-model-smoke.sh",
    "run-knowledge-widget-snapshot-reader-model-smoke.sh",
    "knowledge-widget-privacy-lifecycle-check.swift",
] {
    contains(releaseRegression, runner, "release regression must run \(runner)")
    contains(releaseQA, runner, "release QA package must require \(runner)")
}

print("Knowledge Widget privacy lifecycle checks passed")
