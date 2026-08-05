import Foundation

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
import UIKit
#endif

/// Centralizes AppDelegate and Echo smoke-harness launch-argument access for
/// Debug and simulator UIQA only.
///
/// Production artifacts intentionally receive an empty configuration so a
/// stale command-line argument can never enable a seed, smoke flow, or hidden
/// harness feature. Keep scenario orchestration outside of this type; it is
/// the fail-closed boundary for the centralized smoke harness.
struct QALaunchConfiguration {
    static let shared = QALaunchConfiguration()

    private let arguments: [String]

    private init() {
        #if DEBUG || UI_QA_SIMULATOR
        arguments = ProcessInfo.processInfo.arguments
        #else
        arguments = []
        #endif
    }

    func contains(_ argument: String) -> Bool {
        arguments.contains(argument)
    }

    func contains(prefix: String) -> Bool {
        arguments.contains { $0.hasPrefix(prefix) }
    }

    func value(forPrefix prefix: String) -> String? {
        arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    var startupScenario: QALaunchScenario? {
        QALaunchScenario.resolve(in: self)
    }

    var shouldEnableArchiveRemoteFetch: Bool {
        contains(QALaunchFeature.archiveRemoteFetch.rawValue)
    }

    var shouldEnableDigitalHumanLivePanel: Bool {
        QALaunchFeature.digitalHumanLivePanelArguments.contains { argument in
            contains(argument.rawValue)
        } || startupScenario?.requiresDigitalHumanLivePanel == true
    }

    var shouldSeedProfileCareFamilyMember: Bool {
        contains(prefix: QALaunchFeature.profileCareScenarioPrefix)
    }
}

/// Non-scenario QA arguments. These may enable an isolated test capability,
/// but do not select one of the AppDelegate smoke flows.
enum QALaunchFeature: String, CaseIterable {
    case archiveRemoteFetch = "DJEnableArchiveRemoteFetch"
    case ownerTruthInterviewNaturalInputEntry = "DJShowOwnerTruthInterviewNaturalInputEntryQA"
    case showDigitalHumanLivePanel = "DJShowDigitalHumanLivePanel"
    case tencentDigitalHumanTextDriveSmoke = "DJRunTencentDigitalHumanTextDriveSmoke"
    case tencentDigitalHumanPCMDriveSmoke = "DJRunTencentDigitalHumanPCMDriveSmoke"
    case tencentDigitalHumanBackendPCMDriveSmoke = "DJRunTencentDigitalHumanBackendPCMDriveSmoke"

    static let profileCareScenarioPrefix = "DJRunProfileCare"

    static let digitalHumanLivePanelArguments: [QALaunchFeature] = [
        .showDigitalHumanLivePanel,
        .tencentDigitalHumanTextDriveSmoke,
        .tencentDigitalHumanPCMDriveSmoke,
        .tencentDigitalHumanBackendPCMDriveSmoke,
    ]
}

/// The only startup UIQA scenario registry. `startupOrder` preserves the
/// legacy AppDelegate if/else priority: when more than one argument is present,
/// the earliest registered scenario is the sole scenario that runs.
enum QALaunchScenario: String, CaseIterable {
    case digitalHumanLivePanelSmoke = "DJRunDigitalHumanLivePanelSmoke"
    case echoDigitalHumanLifecycleSmoke = "DJRunEchoDigitalHumanLifecycleSmoke"
    case echoAudioOwnerCoordinatorSmoke = "DJRunEchoAudioOwnerCoordinatorSmoke"
    case echoContinuousTurnSmoke = "DJRunEchoContinuousTurnSmoke"
    case digitalHumanRuntimeStubSmoke = "DJRunDigitalHumanRuntimeStubSmoke"
    case voiceCloneProfileSelectionSmoke = "DJRunVoiceCloneProfileSelectionSmoke"
    case voiceCloneSynthesisRuntimeSmoke = "DJRunVoiceCloneSynthesisRuntimeSmoke"
    case voiceCloneOwnerScopeSmoke = "DJRunVoiceCloneOwnerScopeSmoke"
    case tencentBackendPCMDriveMockSmoke = "DJRunTencentBackendPCMDriveMockSmoke"
    case echoTraceExportSmoke = "DJRunEchoTraceExportSmoke"
    case echoRuntimeDiagnosticsExportSmoke = "DJRunEchoRuntimeDiagnosticsExportSmoke"
    case echoTraceEvidencePackageExportSmoke = "DJRunEchoTraceEvidencePackageExportSmoke"
    case echoTraceEvidencePackagePanelExportSmoke = "DJRunEchoTraceEvidencePackagePanelExportSmoke"
    case echoQAEvidenceBundleExportSmoke = "DJRunEchoQAEvidenceBundleExportSmoke"
    case profileCareBackendFailureRetrySmoke = "DJRunProfileCareBackendFailureRetrySmoke"
    case profileCareBackendStateSmoke = "DJRunProfileCareBackendStateSmoke"
    case profileCareStateSmoke = "DJRunProfileCareStateSmoke"
    case profileCareEscalationBoundarySmoke = "DJRunProfileCareEscalationBoundarySmoke"
    case profileFamilyPersonaReleaseSmoke = "DJRunProfileFamilyPersonaReleaseSmoke"
    case publicationManagementM2Smoke = "DJRunPublicationManagementM2Smoke"
    case publicationLifecycleM2Smoke = "DJRunPublicationLifecycleM2Smoke"
    case globalPrivateStoreRetirementSmoke = "DJRunGlobalPrivateStoreRetirementSmoke"
    case archiveMediaEntriesSmoke = "DJRunArchiveMediaEntriesSmoke"
    case archiveAudioLifecycleSmoke = "DJRunArchiveAudioLifecycleSmoke"
    case archiveHiddenShellSmoke = "DJRunArchiveHiddenShellSmoke"
    case ownerMediaUnifiedCreationSmoke = "DJRunOwnerMediaUnifiedCreationSmoke"
    case ownerMediaTaskStatusSmoke = "DJRunOwnerMediaTaskStatusSmoke"
    case ownerTruthCandidateInboxSmoke = "DJRunOwnerTruthCandidateInboxSmoke"
    case ownerTruthInterviewCandidateReviewSmoke = "DJRunOwnerTruthInterviewCandidateReviewSmoke"
    case ownerTruthInterviewSessionStateSmoke = "DJRunOwnerTruthInterviewSessionStateSmoke"
    case ownerTruthInterviewOrchestrationSmoke = "DJRunOwnerTruthInterviewOrchestrationSmoke"
    case ownerTruthInterviewTopicSwitchSmoke = "DJRunOwnerTruthInterviewTopicSwitchSmoke"
    case ownerTruthInterviewPacingSmoke = "DJRunOwnerTruthInterviewPacingSmoke"
    case ownerTruthInterviewNaturalInputSmoke = "DJRunOwnerTruthInterviewNaturalInputSmoke"
    case ownerTruthKnowledgeDimensionConfirmationSmoke = "DJRunOwnerTruthKnowledgeDimensionConfirmationSmoke"
    case ownerTruthKnowledgeRecommendationPlanSmoke = "DJRunOwnerTruthKnowledgeRecommendationPlanSmoke"
    case ownerTruthInterviewBoundarySmoke = "DJRunOwnerTruthInterviewBoundarySmoke"
    case ownerTruthInterviewNaturalInputEchoSurfaceSmoke = "DJRunOwnerTruthInterviewNaturalInputEchoSurfaceSmoke"
    case ownerTruthInterviewNaturalInputProductSurfaceSmoke = "DJRunOwnerTruthInterviewNaturalInputProductSurfaceSmoke"
    case ownerTruthInterviewCandidateProposalReviewReadySmoke = "DJRunOwnerTruthInterviewCandidateProposalReviewReadySmoke"
    case ownerTruthInterviewCandidateConfirmationFailClosedSmoke = "DJRunOwnerTruthInterviewCandidateConfirmationFailClosedSmoke"
    case ownerTruthInterviewCandidateConfirmationSourceInactiveSmoke = "DJRunOwnerTruthInterviewCandidateConfirmationSourceInactiveSmoke"
    case ownerTruthLifeMapPresentationSmoke = "DJRunOwnerTruthLifeMapPresentationSmoke"
    case ownerTruthMemorySearchPresentationSmoke = "DJRunOwnerTruthMemorySearchPresentationSmoke"
    case ownerTruthInterviewOutcomePresentationSmoke = "DJRunOwnerTruthInterviewOutcomePresentationSmoke"
    case archiveFailedAnalysisRetrySmoke = "DJRunArchiveFailedAnalysisRetrySmoke"
    case echoDelayedReplyNotificationSmoke = "DJRunEchoDelayedReplyNotificationSmoke"
    case notificationRuntimeRouteSmoke = "DJRunNotificationRuntimeRouteSmoke"
    case backendEnvironmentSmoke = "DJRunBackendEnvSmoke"
    case archiveToEchoSmoke = "DJRunArchiveToEchoSmoke"
    case archiveMediaEchoContextSmoke = "DJRunArchiveMediaEchoContextSmoke"
    case timeLetterDispatchReminderSmoke = "DJRunTimeLetterDispatchReminderSmoke"
    case echoListeningStatePreview = "DJShowEchoListeningStatePreview"
    case echoSpeakingStatePreview = "DJShowEchoSpeakingStatePreview"
    case voiceSDKReadinessPreview = "DJShowVoiceSDKReadinessPreview"
    case voiceCloneStatusFeedbackPreview = "DJShowVoiceCloneStatusFeedbackPreview"
    case echoVoiceStatePreview = "DJShowEchoVoiceStatePreview"
    case seedEchoArchiveContext = "DJSeedEchoArchiveContext"
    case seedArchiveAnalysisInsights = "DJSeedArchiveAnalysisInsights"
    case seedPendingArchiveAnalysis = "DJSeedPendingArchiveAnalysis"

    static let startupOrder: [QALaunchScenario] = [
        .digitalHumanLivePanelSmoke,
        .echoDigitalHumanLifecycleSmoke,
        .echoAudioOwnerCoordinatorSmoke,
        .echoContinuousTurnSmoke,
        .digitalHumanRuntimeStubSmoke,
        .voiceCloneProfileSelectionSmoke,
        .voiceCloneSynthesisRuntimeSmoke,
        .voiceCloneOwnerScopeSmoke,
        .tencentBackendPCMDriveMockSmoke,
        .echoTraceExportSmoke,
        .echoRuntimeDiagnosticsExportSmoke,
        .echoTraceEvidencePackageExportSmoke,
        .echoTraceEvidencePackagePanelExportSmoke,
        .echoQAEvidenceBundleExportSmoke,
        .profileCareBackendFailureRetrySmoke,
        .profileCareBackendStateSmoke,
        .profileCareStateSmoke,
        .profileCareEscalationBoundarySmoke,
        .profileFamilyPersonaReleaseSmoke,
        .publicationManagementM2Smoke,
        .publicationLifecycleM2Smoke,
        .globalPrivateStoreRetirementSmoke,
        .archiveMediaEntriesSmoke,
        .archiveAudioLifecycleSmoke,
        .archiveHiddenShellSmoke,
        .ownerMediaUnifiedCreationSmoke,
        .ownerMediaTaskStatusSmoke,
        .ownerTruthCandidateInboxSmoke,
        .ownerTruthInterviewCandidateReviewSmoke,
        .ownerTruthInterviewSessionStateSmoke,
        .ownerTruthInterviewOrchestrationSmoke,
        .ownerTruthInterviewTopicSwitchSmoke,
        .ownerTruthInterviewPacingSmoke,
        .ownerTruthInterviewNaturalInputSmoke,
        .ownerTruthKnowledgeDimensionConfirmationSmoke,
        .ownerTruthKnowledgeRecommendationPlanSmoke,
        .ownerTruthInterviewBoundarySmoke,
        .ownerTruthInterviewNaturalInputEchoSurfaceSmoke,
        .ownerTruthInterviewNaturalInputProductSurfaceSmoke,
        .ownerTruthInterviewCandidateProposalReviewReadySmoke,
        .ownerTruthInterviewCandidateConfirmationFailClosedSmoke,
        .ownerTruthInterviewCandidateConfirmationSourceInactiveSmoke,
        .ownerTruthLifeMapPresentationSmoke,
        .ownerTruthMemorySearchPresentationSmoke,
        .ownerTruthInterviewOutcomePresentationSmoke,
        .archiveFailedAnalysisRetrySmoke,
        .echoDelayedReplyNotificationSmoke,
        .notificationRuntimeRouteSmoke,
        .backendEnvironmentSmoke,
        .archiveToEchoSmoke,
        .archiveMediaEchoContextSmoke,
        .timeLetterDispatchReminderSmoke,
        .echoListeningStatePreview,
        .echoSpeakingStatePreview,
        .voiceSDKReadinessPreview,
        .voiceCloneStatusFeedbackPreview,
        .echoVoiceStatePreview,
        .seedEchoArchiveContext,
        .seedArchiveAnalysisInsights,
        .seedPendingArchiveAnalysis,
    ]

    static func resolve(in configuration: QALaunchConfiguration) -> QALaunchScenario? {
        startupOrder.first { configuration.contains($0.rawValue) }
    }

    var sessionPreparation: QALaunchScenarioSessionPreparation {
        switch self {
        case .globalPrivateStoreRetirementSmoke,
             .voiceCloneOwnerScopeSmoke,
             .backendEnvironmentSmoke,
             .seedEchoArchiveContext,
             .seedArchiveAnalysisInsights,
             .seedPendingArchiveAnalysis:
            return .none
        // The archive seed is created after Scene composition, but the
        // prevalidated test credential must exist before that composition
        // so AccountLease-protected archive storage is available.
        case .archiveToEchoSmoke:
            return .login
        case .voiceCloneProfileSelectionSmoke,
             .voiceCloneSynthesisRuntimeSmoke,
             .profileCareBackendFailureRetrySmoke,
             .profileCareBackendStateSmoke,
             .profileCareStateSmoke,
             .profileFamilyPersonaReleaseSmoke,
             .publicationManagementM2Smoke,
             .publicationLifecycleM2Smoke,
             .archiveMediaEntriesSmoke,
             .archiveAudioLifecycleSmoke,
             .archiveHiddenShellSmoke,
             .ownerMediaUnifiedCreationSmoke,
             .ownerMediaTaskStatusSmoke,
             .ownerTruthCandidateInboxSmoke,
             .ownerTruthInterviewCandidateReviewSmoke,
             .ownerTruthInterviewSessionStateSmoke,
             .ownerTruthInterviewOrchestrationSmoke,
             .ownerTruthInterviewTopicSwitchSmoke,
             .ownerTruthInterviewPacingSmoke,
             .ownerTruthInterviewNaturalInputSmoke,
             .ownerTruthKnowledgeDimensionConfirmationSmoke,
             .ownerTruthKnowledgeRecommendationPlanSmoke,
             .ownerTruthMemorySearchPresentationSmoke,
             .ownerTruthInterviewOutcomePresentationSmoke,
             .archiveFailedAnalysisRetrySmoke,
             .timeLetterDispatchReminderSmoke:
            return .loginAndResetFeatureFlags
        default:
            return .login
        }
    }

    var requiresDigitalHumanLivePanel: Bool {
        switch self {
        case .digitalHumanLivePanelSmoke,
             .echoDigitalHumanLifecycleSmoke,
             .digitalHumanRuntimeStubSmoke,
             .tencentBackendPCMDriveMockSmoke:
            return true
        default:
            return false
        }
    }

    /// These backend-backed Profile smokes must use a real, isolated V2 user
    /// session. They intentionally do not inherit the synthetic UIQA login:
    /// the client must prove its principal/owner checks before it can reach a
    /// user-owned care route.
    var requiresAuthenticatedBackendFixture: Bool {
        switch self {
        case .profileCareBackendFailureRetrySmoke,
             .profileCareBackendStateSmoke:
            return true
        default:
            return false
        }
    }

    /// Keep UIQA startup timing declarative so AppDelegate dispatch does not
    /// accumulate per-scenario magic delays. `nil` means the legacy path is
    /// intentionally immediate because it only prepares a local QA seed.
    var startupDelay: TimeInterval? {
        switch self {
        case .archiveMediaEchoContextSmoke,
             .seedEchoArchiveContext,
             .seedArchiveAnalysisInsights,
             .seedPendingArchiveAnalysis:
            return nil
        case .digitalHumanLivePanelSmoke,
             .echoDigitalHumanLifecycleSmoke,
             .echoAudioOwnerCoordinatorSmoke,
             .echoContinuousTurnSmoke,
             .digitalHumanRuntimeStubSmoke,
             .tencentBackendPCMDriveMockSmoke,
             .echoTraceExportSmoke,
             .echoRuntimeDiagnosticsExportSmoke,
             .echoTraceEvidencePackageExportSmoke,
             .echoTraceEvidencePackagePanelExportSmoke,
             .echoQAEvidenceBundleExportSmoke,
             .backendEnvironmentSmoke,
             .archiveToEchoSmoke,
             .echoListeningStatePreview,
             .echoSpeakingStatePreview,
             .voiceSDKReadinessPreview,
             .voiceCloneStatusFeedbackPreview,
             .echoVoiceStatePreview:
            return 1.0
        default:
            return 0.8
        }
    }
}

enum QALaunchScenarioSessionPreparation {
    case none
    case login
    case loginAndResetFeatureFlags
}

/// A compile-contained QA support facade. It owns launch planning and session
/// preparation while AppDelegate keeps the temporary bridge to existing smoke
/// method bodies. This lets the QA orchestration move incrementally without
/// exposing a public runtime entry point or touching product composition.
struct QAScenarioLaunchPlan {
    let scenario: QALaunchScenario?
    let shouldEnableArchiveRemoteFetch: Bool
    let shouldEnableDigitalHumanLivePanel: Bool
    let shouldSeedProfileCareFamilyMember: Bool

    var sessionPreparation: QALaunchScenarioSessionPreparation? {
        scenario?.sessionPreparation
    }
}

enum QAScenarioRunner {
    static func makeLaunchPlan(from configuration: QALaunchConfiguration) -> QAScenarioLaunchPlan {
        QAScenarioLaunchPlan(
            scenario: configuration.startupScenario,
            shouldEnableArchiveRemoteFetch: configuration.shouldEnableArchiveRemoteFetch,
            shouldEnableDigitalHumanLivePanel: configuration.shouldEnableDigitalHumanLivePanel,
            shouldSeedProfileCareFamilyMember: configuration.shouldSeedProfileCareFamilyMember
        )
    }

    static func prepareSession(
        for plan: QAScenarioLaunchPlan,
        login: () -> Void,
        resetFeatureFlags: () -> Void
    ) {
        switch plan.sessionPreparation {
        case nil, .some(.none):
            return
        case .some(.login):
            login()
        case .some(.loginAndResetFeatureFlags):
            login()
            resetFeatureFlags()
        }
    }

    static func schedule(
        _ scenario: QALaunchScenario,
        scheduleAfter: @escaping (_ delay: TimeInterval, _ action: @escaping () -> Void) -> Void,
        action: @escaping () -> Void
    ) {
        guard let delay = scenario.startupDelay else {
            action()
            return
        }
        scheduleAfter(delay, action)
    }
}

#if DEBUG || UI_QA_SIMULATOR
/// Shared, compile-isolated result writer for deterministic UIQA smoke output.
/// Scenario-specific code retains ownership of result names and log labels;
/// this type only owns JSON encoding and atomic file persistence.
enum QAScenarioResultWriter {
    enum WriteError: Error {
        case resultEncoding
        case resultWrite(Error)
    }

    static func write(
        _ result: [String: Any],
        fileName: String,
        directory: URL? = nil
    ) throws -> URL {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let outputDirectory = directory ?? FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
              ).first else {
            throw WriteError.resultEncoding
        }

        let outputURL = outputDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: outputURL, options: [.atomic])
            return outputURL
        } catch {
            throw WriteError.resultWrite(error)
        }
    }

    /// Emits a deterministic UIQA result without routing smoke persistence
    /// through AppDelegate. This remains compile-isolated from release builds.
    static func writeAndLog(
        _ result: [String: Any],
        fileName: String,
        smokeName: String
    ) {
        do {
            let resultURL = try write(result, fileName: fileName)
            print("[UI_QA] \(smokeName) result=\(resultURL.path)")
        } catch WriteError.resultEncoding {
            print("[UI_QA] \(smokeName) failed reason=resultEncoding")
        } catch WriteError.resultWrite(let error) {
            print("[UI_QA] \(smokeName) failed reason=resultWrite error=\(error.localizedDescription)")
        } catch {
            print("[UI_QA] \(smokeName) failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}
#endif

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
/// Shared route/retry orchestration for Echo UIQA smokes. Scenario-specific
/// operations, output labels, and result adapters stay explicit at the call
/// site, while this runner owns only the repeated UIQA navigation mechanics.
enum QAEchoScenarioRunner {
    private static let maximumRootRetries = 20
    private static let rootRetryDelay: TimeInterval = 0.25

    static func run(
        retryCount: Int,
        smokeName: String,
        retry: @escaping (_ retryCount: Int) -> Void,
        writeResult: @escaping (_ result: [String: Any]) -> Void,
        execute: @escaping (
            _ echoViewController: EchoViewController,
            _ completion: @escaping ([String: Any]) -> Void
        ) -> Void,
        completionLog: @escaping (_ result: [String: Any]) -> Void
    ) {
        guard let tabBarController = keyWindowRootViewController() as? WarmTabBarController else {
            guard retryCount < maximumRootRetries else {
                fail(smokeName: smokeName, reason: "missingRootTab", writeResult: writeResult)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + rootRetryDelay) {
                retry(retryCount + 1)
            }
            return
        }

        guard let viewControllers = tabBarController.viewControllers,
              viewControllers.count > 1,
              let echoNavigationController = viewControllers[1] as? UINavigationController,
              let echoViewController = echoNavigationController.viewControllers.first as? EchoViewController else {
            fail(smokeName: smokeName, reason: "missingEcho", writeResult: writeResult)
            return
        }

        tabBarController.selectedIndex = 1
        execute(echoViewController) { payload in
            var result = payload
            result["selectedTabIndex"] = tabBarController.selectedIndex
            writeResult(result)
            completionLog(result)
        }
    }

    private static func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }

    private static func fail(
        smokeName: String,
        reason: String,
        writeResult: ([String: Any]) -> Void
    ) {
        print("[UI_QA] \(smokeName) failed reason=\(reason)")
        writeResult([
            "completed": false,
            "failureReason": reason
        ])
    }
}

/// Shared Profile-tab routing and result persistence for UIQA-only scenarios.
/// It intentionally contains no care, family, or backend business rules; each
/// smoke keeps those assertions at its call site while AppDelegate stays a
/// launch bridge.
enum QAProfileScenarioRunner {
    static func selectRootProfileTab() -> Bool {
        selectRootProfileNavigationController() != nil
    }

    static func selectRootProfileViewController() -> ProfileViewController? {
        guard let profileNavigationController = selectRootProfileNavigationController() else {
            return nil
        }
        return profileNavigationController.viewControllers.first as? ProfileViewController
    }

    private static func selectRootProfileNavigationController() -> UINavigationController? {
        guard let tabBarController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController as? WarmTabBarController,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController else {
            return nil
        }

        profileNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2
        return profileNavigationController
    }

    static func writeResult(
        _ result: [String: Any],
        fileName: String,
        smokeName: String
    ) {
        do {
            let resultURL = try QAScenarioResultWriter.write(result, fileName: fileName)
            print("[UI_QA] \(smokeName) result=\(resultURL.path)")
        } catch QAScenarioResultWriter.WriteError.resultEncoding {
            print("[UI_QA] \(smokeName) failed reason=resultEncoding")
        } catch {
            print("[UI_QA] \(smokeName) failed reason=resultWrite error=\(error.localizedDescription)")
        }
    }
}

/// Consumes one short-lived, server-issued UIQA session from the Simulator
/// Documents directory. The shell harness writes this file after installation
/// and before launch, then this type removes it immediately after decoding.
/// It is compiled only into simulator QA artifacts and never accepts a token
/// through build settings or process arguments.
enum QAAuthenticatedBackendSessionFixture {
    private static let fileName = "uiqa-profile-care-auth-session.json"

    static func prepare(
        expectedUserId: String,
        completion: @escaping (String?) -> Void
    ) {
        let normalizedExpectedUserId = expectedUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedExpectedUserId.isEmpty else {
            completion("missingExpectedUserId")
            return
        }
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            completion("missingDocumentsDirectory")
            return
        }

        let fixtureURL = documentsDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fixtureURL) else {
            completion("missingAuthenticatedBackendFixture")
            return
        }
        defer { try? FileManager.default.removeItem(at: fixtureURL) }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = object["userId"] as? String,
              let phone = object["phone"] as? String,
              let nickname = object["nickname"] as? String,
              let auth = object["auth"] as? [String: Any],
              userId == normalizedExpectedUserId,
              let session = BackendAuthSessionContract(json: auth),
              session.isPrivateAccessEligible(for: normalizedExpectedUserId) else {
            completion("invalidAuthenticatedBackendFixture")
            return
        }

        do {
            try BackendAuthSessionStore.shared.save(session)
        } catch {
            completion("authenticatedBackendSessionSaveFailed")
            return
        }
        guard UserManager.shared.loginVerifiedAccount(
            phone: phone,
            nickname: nickname,
            userId: normalizedExpectedUserId
        ), let credential = UserManager.shared.accountSessionCredentialSnapshot(),
          credential.trust == .requiresOnlineValidation,
          credential.normalizedSubjectId == normalizedExpectedUserId else {
            BackendAuthSessionStore.shared.clear(ifCurrentMatches: session)
            completion("authenticatedBackendSessionAdoptionFailed")
            return
        }

        // Scene composition owns AccountSessionActor activation. Calling the
        // actor here races the SceneDelegate cold-start bootstrap and can leave
        // the app visually on the login root despite an otherwise valid V2
        // fixture. AppDelegate asks the existing AppCoordinator to perform the
        // same verified-login transition once a scene is available.
        print("[UI_QA] Authenticated backend fixture prepared for profile care smoke")
        completion(nil)
    }
}
#endif

enum DJFeature: String, CaseIterable {
    case echoTextInput
    case echoGuidedRecommendations
    case ownerTruthLifeMap
    case ownerTruthMemorySearch
    case ownerTruthInterviewOutcome
    case ownerTruthCandidateReview
    case ownerTextCaptureV1
    case ownerMediaCaptureV1
    case echoImageInput
    case timeLetters
    case profileSettings
    case personaSettings
    case archiveAudioUpload
    case archiveVideoUpload
    case archiveRemoteFetch
    case archiveLocalAnalysis
    case familyManagement
    case familySpace
    case legalCenter
    case accountDeletion
    case accountPasswordChange
    case careDashboard
    case careDoctorContact
    case voiceCloneShell
    case digitalHumanLivePanel
    case publicationVisitorM2
    case publicationManagementM2
}

final class FeatureFlagService {
    static let shared = FeatureFlagService()

    private static let storageKey = "dj.featureFlags.enabled"
    private static let storageVersionKey = "dj.featureFlags.schemaVersion"
    private static let currentStorageVersion = 11
    private static let defaultEnabled: Set<DJFeature> = [
        .echoTextInput,
        .profileSettings,
        .legalCenter,
        .accountDeletion,
    ]
    private static let nonPersistentFeatures: Set<DJFeature> = [
        .echoImageInput,
        .echoGuidedRecommendations,
        .ownerTruthLifeMap,
        .ownerTruthMemorySearch,
        .ownerTruthInterviewOutcome,
        .ownerTruthCandidateReview,
        .ownerTextCaptureV1,
        .ownerMediaCaptureV1,
        .timeLetters,
        .personaSettings,
        .archiveAudioUpload,
        .archiveVideoUpload,
        .archiveRemoteFetch,
        .archiveLocalAnalysis,
        .familyManagement,
        .familySpace,
        .accountPasswordChange,
        .careDashboard,
        .careDoctorContact,
        .voiceCloneShell,
        .digitalHumanLivePanel,
        .publicationVisitorM2,
        .publicationManagementM2,
    ]

    private var enabled: Set<DJFeature>
    private var transientEnabled: Set<DJFeature> = []

    private init() {
        let storedVersion = UserDefaults.standard.integer(forKey: Self.storageVersionKey)
        if storedVersion == Self.currentStorageVersion,
           let rawValues = UserDefaults.standard.array(forKey: Self.storageKey) as? [String] {
            self.enabled = Set(rawValues.compactMap(DJFeature.init(rawValue:))).subtracting(Self.nonPersistentFeatures)
            persist()
        } else {
            self.enabled = Self.defaultEnabled
            persist()
        }
    }

    func isEnabled(_ feature: DJFeature) -> Bool {
        enabled.contains(feature) || transientEnabled.contains(feature)
    }

    func set(_ feature: DJFeature, enabled isEnabled: Bool) {
        if Self.nonPersistentFeatures.contains(feature) {
            enabled.remove(feature)
            #if DEBUG || UI_QA_SIMULATOR
            if isEnabled {
                transientEnabled.insert(feature)
            } else {
                transientEnabled.remove(feature)
            }
            #else
            transientEnabled.remove(feature)
            #endif
            persist()
            return
        }

        if isEnabled {
            enabled.insert(feature)
        } else {
            enabled.remove(feature)
        }
        persist()
    }

    #if DEBUG || UI_QA_SIMULATOR
    func enableForCurrentLaunch(_ feature: DJFeature) {
        transientEnabled.insert(feature)
    }
    #endif

    func resetToDefaults() {
        enabled = Self.defaultEnabled
        transientEnabled.removeAll()
        persist()
    }

    private func persist() {
        let rawValues = enabled.map(\.rawValue).sorted()
        UserDefaults.standard.set(rawValues, forKey: Self.storageKey)
        UserDefaults.standard.set(Self.currentStorageVersion, forKey: Self.storageVersionKey)
    }
}
