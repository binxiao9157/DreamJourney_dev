import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Knowledge pipeline guard failed: \(message)\n", stderr)
        exit(1)
    }
}

func requireOrdered(_ content: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = content.range(of: first),
          let secondRange = content.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fputs("Knowledge pipeline guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
let generationPolicy = read("DreamJourney/Sources/Services/KnowledgeGenerationPolicy.swift")
let coordinator = read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let threeWayMerge = read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")
let backend = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let sceneDelegate = read("DreamJourney/Sources/SceneDelegate.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let regression = read("scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(
    manager.contains("func switchUser(to userId: String?)") &&
        manager.contains("private(set) var loadedUserId") &&
        manager.contains("userGeneration") &&
        manager.contains("丢弃旧用户知识提取结果") &&
        manager.contains("moveItem(at: legacyFile, to: userFile)") &&
        manager.contains("widgetSnapshotStore.activate(") &&
        manager.contains("widgetSnapshotStore.publish("),
    "KBLite should isolate in-memory graphs by user, migrate the legacy file once, and publish Widget data through the guarded lifecycle store"
)

require(
    manager.contains("DreamJourneyBackendClient.shared.extractKnowledgeEnvelope(") &&
        !manager.contains("DeepSeekService.shared.extractKnowledge") &&
        manager.contains("fallbackReason: \"backendNotConfigured\"") &&
        manager.contains("KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: \"extractionCompleted\")"),
    "KBLite extraction should be backend-first with explicit local fallback and sync trigger"
)

require(
    manager.contains("func buildGenerationAllowedContextString(") &&
        manager.contains("KnowledgeGenerationPolicy.allowsEntity(") &&
        manager.contains("KnowledgeGenerationPolicy.allowsFact(") &&
        generationPolicy.contains("privacyScope == \"generationAllowed\"") &&
        generationPolicy.contains("case \"high\", \"confirmed\"") &&
        manager.contains("loadedUserId == identity.ownerUserId") &&
        echo.contains("KBLiteManager.shared.buildGenerationAllowedContextString("),
    "local Echo fallback must only expose generationAllowed knowledge"
)

require(
    coordinator.contains("fetchKnowledgeChanges(") &&
        coordinator.contains("mutateKnowledgeV2(") &&
        coordinator.contains("mutateKnowledge(") &&
        coordinator.contains("pushLegacySnapshot") &&
        coordinator.contains("BackendAuthSessionStore.shared.currentSession?.userId == userId") &&
        coordinator.contains("isRevisionConflict") &&
        coordinator.contains("isOperationPayloadConflict") &&
        coordinator.contains("recoverPendingOperationConflict") &&
        coordinator.contains("KnowledgeRemoteBaseStore") &&
        coordinator.contains("KnowledgePendingMutationStore") &&
        coordinator.contains("KnowledgeSyncGraphEngine.makeDelta") &&
        coordinator.contains("KnowledgeMutationV2FallbackPolicy.shouldFallback") &&
        coordinator.contains("queue.sync") &&
        coordinator.contains("KBLiteManager.shared.loadedUserId == userId") &&
        coordinator.contains("beginKnowledgePull(") &&
        coordinator.contains("pullNextKnowledgePage(") &&
        coordinator.contains("commitKnowledgePull(") &&
        coordinator.contains("applySyncedGraphCAS") &&
        !coordinator.contains("didApplyChanges("),
    "sync coordinator should page to a stable target, commit only the terminal snapshot, persist a remote base, reuse pending V2 mutations, and retain legacy fallback"
)

require(
    threeWayMerge.contains("static func bootstrap(") &&
        threeWayMerge.contains("static func merge(") &&
        threeWayMerge.contains("static func makeDelta(") &&
        threeWayMerge.contains("local private entity") &&
        threeWayMerge.contains("qaConflictSummary") &&
        threeWayMerge.contains("KnowledgeChangeFeedReducer") &&
        threeWayMerge.contains("KnowledgeGraphCASPolicy") &&
        threeWayMerge.contains("KnowledgeRemoteBaseStore") &&
        threeWayMerge.contains("KnowledgePendingMutationStore"),
    "knowledge sync model should own bootstrap, three-way merge, tombstones, privacy protection, and per-user file persistence"
)

require(
    backend.contains("struct BackendErrorContext: Equatable") &&
        backend.contains("normalizedBackendErrorString(detail[\"code\"])") &&
        coordinator.contains("context.code == \"knowledgeOperationPayloadConflict\"") &&
        coordinator.contains("pendingOperationDiscarded") &&
        !coordinator.contains("detail.contains(\"knowledgeRevisionConflict\")"),
    "knowledge conflicts must consume structured backend codes and discard poisoned operation IDs"
)

require(
    manager.contains("local.people.filter { !isRemotelySyncable($0.privacyMetadata) }") &&
        manager.contains("scope == \"generationAllowed\" || scope == \"familyCircle\""),
    "authoritative remote snapshots must preserve localOnly and legacy local entities"
)

require(
    backend.contains("var isKnowledgeSyncConfigured") &&
        backend.contains("func mutateKnowledge(") &&
        backend.contains("func mutateKnowledgeV2(") &&
        backend.contains("\"mutationSchemaVersion\": 2") &&
        backend.contains("func fetchKnowledgeChanges(") &&
        backend.contains("Result<KnowledgeChangePage, Error>") &&
        backend.contains("URLQueryItem(name: \"targetRevision\"") &&
        backend.contains("func extractKnowledge("),
    "backend client should expose unified knowledge contracts"
)

require(
    backend.contains("generationContextText") &&
        backend.contains("generationContextContentHash") &&
        backend.contains("generationContextSourceRefs"),
    "Context Packet should parse the backend generation context contract"
)

require(
    dialogEngine.contains("func submitTurnKnowledgeContext(") &&
        dialogEngine.contains("SEDirectiveEventChatRagText") &&
        dialogEngine.contains("usesTurnScopedKnowledgeContext") &&
        dialogEngine.contains("!usesTurnScopedKnowledgeContext"),
    "Dialog engine should submit one-turn RAG context and suppress duplicate startup knowledge"
)

require(
    echo.contains("EchoTurnKnowledgeContextGate") &&
        echo.contains("latestEchoContextRequestTurnID == turnID") &&
        echo.contains("generationContextText") &&
        echo.contains("KBLiteManager.shared.buildGenerationAllowedContextString(") &&
        echo.contains("expectedIdentity: gate.expectedIdentity") &&
        echo.contains("echoTurnKnowledgeTimeout") &&
        echo.contains("submitTurnKnowledgeContext("),
    "Echo should prefer backend generation context and use query-scoped KBLite on timeout"
)


requireOrdered(
    echo,
    "let submitted = DialogEngineManager.shared.submitTurnKnowledgeContext(",
    "gate.didSubmit = true",
    "Echo must consume the turn gate only after the SDK accepts the RAG payload"
)

require(
    echo.contains("if submitted {") &&
        echo.contains("failedSubmissionCount < 2") &&
        echo.contains("scheduleEchoTurnKnowledgeContextRetry"),
    "a rejected SDK RAG submission should retain the gate and perform a bounded retry"
)

require(
    userManager.contains("KBLiteManager.shared.switchUser(to: user.id)") &&
        userManager.contains("KBLiteManager.shared.switchUser(to: nil)") &&
        appDelegate.contains("KnowledgeSyncCoordinator.shared.userDidChange(to: currentKnowledgeUserId)") &&
        sceneDelegate.contains("synchronizeCurrentUser(reason: \"foreground\")"),
    "login, logout, app restore, and foreground should drive the knowledge lifecycle"
)


requireOrdered(
    userManager,
    "KnowledgeSyncCoordinator.shared.userDidChange(to: user.id)",
    "KBLiteManager.shared.switchUser(to: user.id)",
    "login must invalidate the previous sync generation before swapping the in-memory graph"
)

require(
    project.contains("KnowledgeSyncCoordinator.swift in Sources") &&
        project.contains("KnowledgeThreeWayMerge.swift in Sources") &&
        regression.contains("knowledge-pipeline-check.swift") &&
        regression.contains("RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE") &&
        releaseQA.contains("knowledge-pipeline-check.swift"),
    "the coordinator and guard should be included in build and release QA"
)

print("Knowledge pipeline guard passed")
