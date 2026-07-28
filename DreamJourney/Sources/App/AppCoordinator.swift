import UIKit

// MARK: - AppCoordinator：根协调器，路由到 Auth 或 Tab
@MainActor
final class AppCoordinator: Coordinator {

    private enum RootMode {
        case unresolved
        case validating
        case auth
        case main
    }

    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private weak var window: UIWindow?
    private let accountSessionActor: AccountSessionActor
    private let appComposition: AppComposition
    private let lifecycleEventForwarder: AppLifecycleEventForwarder
    private let notificationRuntimeRouteInbox: NotificationRuntimeRouteInbox
    private var rootMode: RootMode = .unresolved
    private var accountSessionReceipt: AccountSessionTransitionReceipt?
    private var accountSessionTask: Task<Void, Never>?
    private weak var activeTabCoordinator: TabCoordinator?
    private var notificationRuntimeRouteObserver: NSObjectProtocol?

    init(
        window: UIWindow,
        accountSessionActor: AccountSessionActor = .shared,
        appComposition: AppComposition? = nil,
        lifecycleEventForwarder: AppLifecycleEventForwarder? = nil,
        notificationRuntimeRouteInbox: NotificationRuntimeRouteInbox = .shared
    ) {
        self.window = window
        self.accountSessionActor = accountSessionActor
        self.appComposition = appComposition ?? AppComposition()
        self.lifecycleEventForwarder = lifecycleEventForwarder ?? AppLifecycleEventForwarder()
        self.notificationRuntimeRouteInbox = notificationRuntimeRouteInbox
        self.navigationController = UINavigationController()
    }

    deinit {
        accountSessionTask?.cancel()
        if let notificationRuntimeRouteObserver {
            NotificationCenter.default.removeObserver(notificationRuntimeRouteObserver)
        }
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        AccountLeaseRuntime.shared.updateAuthorityEpoch(
            RecoveryRuntimePolicyStore.shared.currentPolicy.authorityEpoch
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: .djUserDidLogout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrivateAccessSuspended),
            name: .djPrivateAccessDidSuspend,
            object: nil
        )
        notificationRuntimeRouteObserver = NotificationCenter.default.addObserver(
            forName: .djNotificationRuntimeRouteQueued,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.routePendingNotificationRuntimeRoutesIfPossible()
            }
        }

        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if QALaunchConfiguration.shared.startupScenario?.requiresAuthenticatedBackendFixture == true {
            // The fixture session is prepared in AppDelegate and must be
            // activated through the coordinator below. A cold-start online
            // validation here would race that handoff and, in the deliberate
            // unreachable-backend smoke, clear the fixture before its failure
            // state can be exercised.
            rootMode = .validating
            showStartupValidationGate()
            return
        }
        #endif
        bootstrapAccountSession()
    }

    func showAuth() {
        guard rootMode != .auth else { return }
        rootMode = .auth
        childCoordinators.removeAll()
        activeTabCoordinator = nil
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.didFinishLogin = { [weak self] in
            self?.removeChild(authCoordinator)
            self?.activateVerifiedLogin()
        }
        addChild(authCoordinator)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        authCoordinator.start()
    }

    func showMainTab() {
        guard accountSessionReceipt?.accepted == true,
              accountSessionReceipt?.state == .active,
              accountSessionReceipt?.rootRoute == .privateUI,
              UserManager.shared.canEnterPrivateUI,
              rootMode != .main,
              let accountSession = accountSessionReceipt?.session,
              let tabCoordinator = appComposition.makeTabCoordinator(
                  accountSession: accountSession,
                  lifecycleGeneration: accountSessionReceipt?.generation ?? 0
              ) else {
            if rootMode != .main {
                transitionToAuth()
            }
            return
        }
        rootMode = .main
        childCoordinators.removeAll()
        activeTabCoordinator = tabCoordinator
        tabCoordinator.didRequestLogout = { [weak self] in
            self?.removeChild(tabCoordinator)
            self?.navigationController = UINavigationController()
            self?.showAuth()
        }
        addChild(tabCoordinator)
        window?.rootViewController = tabCoordinator.tabBarController
        window?.makeKeyAndVisible()
        tabCoordinator.start()
        routePendingNotificationRuntimeRoutesIfPossible()
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    /// QA-only bridge for a server-issued fixture session. It deliberately
    /// reuses the same coordinator transition as a verified interactive login
    /// so simulator smokes cannot bypass root composition or AccountLease.
    func activateVerifiedLoginForUIQA(
        completion: @escaping (_ accepted: Bool, _ reason: String) -> Void
    ) {
        activateVerifiedLogin(completion: completion)
    }
    #endif

    /// App/Scene ingress can queue a route before account bootstrap completes.
    /// This method intentionally routes only after `showMainTab` has established
    /// a valid AccountLease; it never starts Echo, Voice, or Digital Human work.
    func receiveNotificationRuntimeRoute(
        userInfo: [AnyHashable: Any],
        source: NotificationRuntimeRouteSource
    ) {
        let result = notificationRuntimeRouteInbox.ingest(
            userInfo: userInfo,
            source: source
        )
        guard result.shouldNotifyRouter else { return }
        routePendingNotificationRuntimeRoutesIfPossible()
    }

    func receiveNotificationRuntimeDeepLink(_ url: URL) {
        let result = notificationRuntimeRouteInbox.ingest(deepLinkURL: url)
        guard result.shouldNotifyRouter else { return }
        routePendingNotificationRuntimeRoutesIfPossible()
    }

    /// SceneDelegate owns only UIKit callback forwarding. The coordinator
    /// captures a coherent account/policy context before any private effect is
    /// allowed to run.
    func handleSceneLifecycleEvent(_ event: AppLifecycleEvent) {
        let runtimeContext = currentFeatureRuntimeContext()
        _ = lifecycleEventForwarder.forward(
            event: event,
            runtimeContext: runtimeContext
        )
    }

    @objc private func handleLogout() {
        accountSessionTask?.cancel()
        accountSessionReceipt = nil
        transitionToAuth()
    }

    @objc private func handlePrivateAccessSuspended() {
        accountSessionTask?.cancel()
        accountSessionReceipt = nil
        transitionToAuth()
    }

    private func bootstrapAccountSession() {
        rootMode = .validating
        showStartupValidationGate()
        let cachedSubjectId = UserManager.shared.currentUser?.id
        let credential = UserManager.shared.accountSessionCredentialSnapshot()
        let priorAccountLease = AccountLeaseRuntime.shared.capture(
            forSubjectId: cachedSubjectId
        )
        accountSessionTask?.cancel()
        accountSessionTask = Task { [weak self, accountSessionActor] in
            let receipt = await accountSessionActor.bootstrap(
                cachedProfileSubjectId: cachedSubjectId,
                credential: credential
            )
            guard !Task.isCancelled, let self else { return }
            self.accountSessionTask = nil
            self.accountSessionReceipt = receipt
            switch receipt.rootRoute {
            case .authentication:
                let oldAccountLease = priorAccountLease
                    ?? self.lifecycleAccountLease(from: receipt.session)
                _ = await AccountLifecycleTransitionController.shared.performAfterExistingFence(
                    event: .coldStartRecovery,
                    oldAccountLease: oldAccountLease,
                    oldGeneration: oldAccountLease?.generation ?? receipt.generation,
                    actorReceipt: receipt
                )
                guard !Task.isCancelled else { return }
                self.transitionToAuth()
            case .validation:
                self.validateCachedPrivateAccess(expectedGeneration: receipt.generation)
            case .privateUI:
                self.showMainTab()
            }
        }
    }

    private func activateVerifiedLogin(
        completion: ((_ accepted: Bool, _ reason: String) -> Void)? = nil
    ) {
        guard let credential = UserManager.shared.accountSessionCredentialSnapshot(),
              credential.trust == .requiresOnlineValidation,
              credential.normalizedSubjectId == UserManager.shared.currentUser?.id else {
            transitionToAuth()
            completion?(false, "verifiedLoginCredentialUnavailable")
            return
        }
        rootMode = .validating
        showStartupValidationGate()
        accountSessionTask?.cancel()
        accountSessionTask = Task { [weak self, accountSessionActor] in
            let receipt = await accountSessionActor.activateVerifiedLogin(credential)
            guard !Task.isCancelled, let self else {
                completion?(false, "verifiedLoginTransitionCancelled")
                return
            }
            self.accountSessionTask = nil
            self.accountSessionReceipt = receipt.accepted ? receipt : nil
            if receipt.accepted, receipt.rootRoute == .privateUI {
                self.showMainTab()
                completion?(self.rootMode == .main, receipt.reason)
            } else {
                self.transitionToAuth()
                completion?(false, receipt.reason)
            }
        }
    }

    private func validateCachedPrivateAccess(expectedGeneration: UInt64) {
        DreamJourneyBackendClient.shared.resumePrivateAccessSession { [weak self] validated in
            DispatchQueue.main.async {
                guard let self,
                      self.accountSessionReceipt?.generation == expectedGeneration else {
                    return
                }
                guard validated,
                      UserManager.shared.canEnterPrivateUI,
                      let credential = UserManager.shared.accountSessionCredentialSnapshot(),
                      credential.trust == .requiresOnlineValidation else {
                    self.suspendActorAndShowAuth(
                        expectedGeneration: expectedGeneration,
                        reason: "startupSessionValidationFailed"
                    )
                    return
                }
                self.accountSessionTask?.cancel()
                let actor = self.accountSessionActor
                self.accountSessionTask = Task { [weak self, actor] in
                    let sessionSaved = await actor.recordActivationPhase(
                        .sessionSaved,
                        expectedGeneration: expectedGeneration
                    )
                    let storesMounted = await actor.recordActivationPhase(
                        .storesMounted,
                        expectedGeneration: expectedGeneration
                    )
                    let profileCached = await actor.recordActivationPhase(
                        .profileCached,
                        expectedGeneration: expectedGeneration
                    )
                    guard sessionSaved.accepted,
                          storesMounted.accepted,
                          profileCached.accepted else {
                        guard let self else { return }
                        self.suspendActorAndShowAuth(
                            expectedGeneration: expectedGeneration,
                            reason: "startupActivationJournalRejected"
                        )
                        return
                    }
                    let receipt = await actor.activateValidatedCredential(
                        credential,
                        expectedGeneration: expectedGeneration
                    )
                    guard !Task.isCancelled,
                          let self,
                          self.accountSessionReceipt?.generation == expectedGeneration else {
                        return
                    }
                    self.accountSessionTask = nil
                    guard receipt.accepted,
                          receipt.rootRoute == .privateUI else {
                        self.suspendActorAndShowAuth(
                            expectedGeneration: expectedGeneration,
                            reason: "startupActorActivationRejected"
                        )
                        return
                    }
                    self.accountSessionReceipt = receipt
                    self.showMainTab()
                }
            }
        }
    }

    private func suspendActorAndShowAuth(expectedGeneration: UInt64?, reason: String) {
        accountSessionTask?.cancel()
        let oldAccountLease = AccountLeaseRuntime.shared.capture(
            forSubjectId: UserManager.shared.currentUser?.id
        ) ?? lifecycleAccountLease(from: accountSessionReceipt?.session)
        let oldGeneration = oldAccountLease?.generation
            ?? expectedGeneration
            ?? accountSessionReceipt?.generation
            ?? 0
        accountSessionTask = Task { [weak self] in
            let result = await AccountLifecycleTransitionController.shared.perform(
                event: .privateSuspension,
                oldAccountLease: oldAccountLease,
                oldGeneration: oldGeneration,
                reason: reason
            )
            guard !Task.isCancelled, let self else { return }
            self.accountSessionTask = nil
            self.accountSessionReceipt = nil
            guard result.lifecycleReceipt.isTerminal else { return }
            self.transitionToAuth()
        }
    }

    private func lifecycleAccountLease(from session: AccountSession?) -> AccountLease? {
        guard let session else { return nil }
        return AccountLease(
            subjectId: session.subjectId,
            vaultId: session.vaultId,
            sessionId: session.sessionId,
            generation: session.generation,
            generationId: session.generationId,
            authorityEpoch: RecoveryRuntimePolicyStore.shared.currentPolicy.authorityEpoch
        )
    }

    private func currentFeatureRuntimeContext() -> AppFeatureRuntimeContext? {
        guard accountSessionReceipt?.accepted == true,
              accountSessionReceipt?.state == .active,
              accountSessionReceipt?.rootRoute == .privateUI,
              let accountSession = accountSessionReceipt?.session else {
            return nil
        }
        return appComposition.makeRuntimeContext(
            accountSession: accountSession,
            lifecycleGeneration: accountSessionReceipt?.generation ?? 0
        )
    }

    private func routePendingNotificationRuntimeRoutesIfPossible() {
        guard rootMode == .main,
              let runtimeContext = currentFeatureRuntimeContext(),
              let activeTabCoordinator,
              AccountLeaseRuntime.shared.validate(
                  runtimeContext.accountLease,
                  at: .request
              ).allowed,
              AccountLeaseRuntime.shared.validate(
                  runtimeContext.accountLease,
                  at: .runtime
              ).allowed,
              AccountLeaseRuntime.shared.validate(
                  runtimeContext.accountLease,
                  at: .ui
              ).allowed else {
            return
        }

        let routes = notificationRuntimeRouteInbox.consumeRoutes(
            accountLease: runtimeContext.accountLease
        )
        for route in routes {
            guard route.accountLease == runtimeContext.accountLease else { continue }
            _ = activeTabCoordinator.selectNotificationRuntimeRoute(
                route,
                runtimeContext: runtimeContext
            )
        }
    }

    private func showStartupValidationGate() {
        let viewController = UIViewController()
        viewController.view.backgroundColor = UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = UIColor(red: 0.63, green: 0.34, blue: 0.06, alpha: 1)
        indicator.startAnimating()
        viewController.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
        ])
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }

    private func transitionToAuth() {
        childCoordinators.removeAll()
        activeTabCoordinator = nil
        navigationController = UINavigationController()
        rootMode = .unresolved
        showAuth()
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
extension AppCoordinator {
    /// Exercises the same root router used by AppDelegate and SceneDelegate.
    /// It contains synthetic opaque route envelopes only; it never invokes a
    /// notification provider, opens a private resource, or starts an audio runtime.
    func runNotificationRuntimeRouteUIQASmoke(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard rootMode == .main,
              let runtimeContext = currentFeatureRuntimeContext(),
              let activeTabCoordinator else {
            completion([
                "completed": false,
                "failureReason": "mainRuntimeUnavailable",
            ])
            return
        }

        let accountLease = runtimeContext.accountLease
        let baselineSnapshot = notificationRuntimeRouteInbox.snapshot()
        let tabBarController = activeTabCoordinator.tabBarController
        let initialSelectedTabIndex = tabBarController.selectedIndex
        let stabilizationDelay = DispatchTimeInterval.milliseconds(150)

        // Route events normally arrive on separate main-loop turns. Preserve that
        // cadence here so a synthetic test cannot leave UIKit mid-appearance when
        // its final screenshot is captured.
        receiveNotificationRuntimeRoute(
            userInfo: uiqaNotificationRuntimeRouteUserInfo(
                accountLease: accountLease,
                kind: .timeLetter,
                operation: "uiqa-route-time-letter"
            ),
            source: .notificationResponse
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + stabilizationDelay) { [weak self] in
            guard let self else {
                completion([
                    "completed": false,
                    "failureReason": "coordinatorReleasedAfterTimeLetterRoute",
                ])
                return
            }
            let timeLetterRouteSelectedArchive = tabBarController.selectedIndex == 0

            self.receiveNotificationRuntimeRoute(
                userInfo: self.uiqaNotificationRuntimeRouteUserInfo(
                    accountLease: accountLease,
                    kind: .echoDelayedReply,
                    operation: "uiqa-route-echo-reply"
                ),
                source: .remoteNotification
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + stabilizationDelay) { [weak self] in
                guard let self else {
                    completion([
                        "completed": false,
                        "failureReason": "coordinatorReleasedAfterEchoRoute",
                    ])
                    return
                }
                let echoRouteSelectedEcho = tabBarController.selectedIndex == 1

                let deepLinkRouteAvailable: Bool
                if let deepLinkURL = self.uiqaNotificationRuntimeRouteDeepLink(
                    accountLease: accountLease,
                    kind: .careSignal,
                    operation: "uiqa-route-care"
                ) {
                    self.receiveNotificationRuntimeDeepLink(deepLinkURL)
                    deepLinkRouteAvailable = true
                } else {
                    deepLinkRouteAvailable = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + stabilizationDelay) { [weak self] in
                    guard let self else {
                        completion([
                            "completed": false,
                            "failureReason": "coordinatorReleasedAfterDeepLinkRoute",
                        ])
                        return
                    }
                    let deepLinkRouteSelectedArchive = deepLinkRouteAvailable
                        && tabBarController.selectedIndex == 0
                    let safeSelectedTabIndex = tabBarController.selectedIndex

                    self.receiveNotificationRuntimeRoute(
                        userInfo: self.uiqaNotificationRuntimeRouteUserInfo(
                            accountLease: accountLease,
                            kind: .familyInvitation,
                            operation: "uiqa-route-cross-owner",
                            resourceOwnerIdentity: NotificationRuntimeRoutePayload.identityDigest(
                                values: ["resource-owner", "uiqa-other-owner"]
                            )
                        ),
                        source: .notificationResponse
                    )
                    let crossOwnerRouteIgnored = tabBarController.selectedIndex == safeSelectedTabIndex

                    self.receiveNotificationRuntimeRoute(
                        userInfo: self.uiqaNotificationRuntimeRouteUserInfo(
                            accountLease: accountLease,
                            kind: .systemNotice,
                            operation: "uiqa-route-stale-generation",
                            generation: accountLease.generation &+ 1
                        ),
                        source: .notificationResponse
                    )
                    let staleGenerationRouteIgnored = tabBarController.selectedIndex == safeSelectedTabIndex

                    self.receiveNotificationRuntimeDeepLink(
                        URL(string: "dreamjourney://runtime-route?type=echoDelayedReply")!
                    )
                    let malformedDeepLinkIgnored = tabBarController.selectedIndex == safeSelectedTabIndex

                    DispatchQueue.main.asyncAfter(deadline: .now() + stabilizationDelay) {
                        let finalSnapshot = self.notificationRuntimeRouteInbox.snapshot()
                        let validRouteDeliveryCount = finalSnapshot.deliveredCount - baselineSnapshot.deliveredCount
                        let rejectedRouteCount = finalSnapshot.rejectedCount - baselineSnapshot.rejectedCount
                        let pendingRoutesDrained = finalSnapshot.queuedCount == baselineSnapshot.queuedCount
                        let finalSelectedTabIndex = tabBarController.selectedIndex
                        let completed = initialSelectedTabIndex == 1
                            && timeLetterRouteSelectedArchive
                            && echoRouteSelectedEcho
                            && deepLinkRouteSelectedArchive
                            && crossOwnerRouteIgnored
                            && staleGenerationRouteIgnored
                            && malformedDeepLinkIgnored
                            && validRouteDeliveryCount == 3
                            && rejectedRouteCount >= 3
                            && pendingRoutesDrained
                            && finalSelectedTabIndex == 0

                        completion([
                            "completed": completed,
                            "failureReason": completed ? "" : "routeContractMismatch",
                            "initialSelectedTabIndex": initialSelectedTabIndex,
                            "timeLetterRouteSelectedArchive": timeLetterRouteSelectedArchive,
                            "echoRouteSelectedEcho": echoRouteSelectedEcho,
                            "deepLinkRouteSelectedArchive": deepLinkRouteSelectedArchive,
                            "crossOwnerRouteIgnored": crossOwnerRouteIgnored,
                            "staleGenerationRouteIgnored": staleGenerationRouteIgnored,
                            "malformedDeepLinkIgnored": malformedDeepLinkIgnored,
                            "validRouteDeliveryCount": validRouteDeliveryCount,
                            "rejectedRouteCount": rejectedRouteCount,
                            "pendingRoutesDrained": pendingRoutesDrained,
                            "finalSelectedTabIndex": finalSelectedTabIndex,
                        ])
                    }
                }
            }
        }
    }

    private func uiqaNotificationRuntimeRouteUserInfo(
        accountLease: AccountLease,
        kind: NotificationRuntimeRouteKind,
        operation: String,
        generation: UInt64? = nil,
        resourceOwnerIdentity: String? = nil
    ) -> [AnyHashable: Any] {
        [
            NotificationRuntimeRoutePayload.Key.schemaVersion: NSNumber(
                value: NotificationRuntimeRoutePayload.schemaVersion
            ),
            NotificationRuntimeRoutePayload.Key.action: NotificationRuntimeRouteAction.open.rawValue,
            NotificationRuntimeRoutePayload.Key.type: kind.rawValue,
            NotificationRuntimeRoutePayload.Key.subjectIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["subject", accountLease.subjectId]
            ),
            NotificationRuntimeRoutePayload.Key.generation: NSNumber(value: generation ?? accountLease.generation),
            NotificationRuntimeRoutePayload.Key.generationIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["generation-id", accountLease.generationId.uuidString]
            ),
            NotificationRuntimeRoutePayload.Key.vaultIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["vault", accountLease.vaultId]
            ),
            NotificationRuntimeRoutePayload.Key.authorityEpochIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["authority-epoch", accountLease.authorityEpoch]
            ),
            NotificationRuntimeRoutePayload.Key.resourceOwnerIdentity: resourceOwnerIdentity
                ?? NotificationRuntimeRoutePayload.identityDigest(
                    values: ["resource-owner", accountLease.subjectId]
                ),
            NotificationRuntimeRoutePayload.Key.operationIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["operation", operation]
            ),
        ]
    }

    private func uiqaNotificationRuntimeRouteDeepLink(
        accountLease: AccountLease,
        kind: NotificationRuntimeRouteKind,
        operation: String
    ) -> URL? {
        let userInfo = uiqaNotificationRuntimeRouteUserInfo(
            accountLease: accountLease,
            kind: kind,
            operation: operation
        )
        var components = URLComponents()
        components.scheme = "dreamjourney"
        components.host = "runtime-route"
        components.queryItems = userInfo.compactMap { key, value in
            guard let name = key as? String else { return nil }
            return URLQueryItem(name: name, value: String(describing: value))
        }
        return components.url
    }
}
#endif

// MARK: - App composition

/// The only root-level factory for the current three-tab private UI. It captures
/// the account lease, lifecycle generation and release-policy authority once at
/// the root boundary before handing construction to feature factories.
@MainActor
final class AppComposition {
    private let featureFactory: AppFeatureFactory
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAuthorityEpochProvider: () -> String

    init(
        featureFactory: AppFeatureFactory? = nil,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAuthorityEpochProvider: @escaping () -> String = {
            RecoveryRuntimePolicyStore.shared.currentPolicy.authorityEpoch
        }
    ) {
        self.featureFactory = featureFactory ?? AppFeatureFactory()
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAuthorityEpochProvider = releasePolicyAuthorityEpochProvider
    }

    func makeTabCoordinator(
        accountSession: AccountSession,
        lifecycleGeneration: UInt64
    ) -> TabCoordinator? {
        guard let runtimeContext = makeRuntimeContext(
            accountSession: accountSession,
            lifecycleGeneration: lifecycleGeneration
        ) else {
            return nil
        }
        return featureFactory.makeTabCoordinator(runtimeContext: runtimeContext)
    }

    func makeRuntimeContext(
        accountSession: AccountSession,
        lifecycleGeneration: UInt64
    ) -> AppFeatureRuntimeContext? {
        guard accountSession.state == .active,
              let accountLease = accountLeaseRuntime.capture(
                  forSubjectId: accountSession.subjectId
              ),
              accountLease.subjectId == accountSession.subjectId,
              accountLease.vaultId == accountSession.vaultId,
              accountLease.sessionId == accountSession.sessionId,
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed,
              let runtimeContext = AppFeatureRuntimeContext(
                  accountLease: accountLease,
                  lifecycleGeneration: lifecycleGeneration,
                  releasePolicyAuthorityEpoch: releasePolicyAuthorityEpochProvider()
              ) else {
            return nil
        }
        return runtimeContext
    }
}

// MARK: - App/Scene lifecycle forwarding

/// Keeps UIKit lifecycle callbacks at the boundary and starts the existing
/// private foreground refresh only after a valid lease was captured. Individual
/// feature runtimes still own their current notification observers until their
/// later lifecycle migration slices.
@MainActor
final class AppLifecycleEventForwarder {
    typealias PrivateForegroundRefresh = (AppFeatureRuntimeContext) -> Void

    private let privateForegroundRefresh: PrivateForegroundRefresh
    private var nextSequence: UInt64 = 0
    private(set) var latestReceipt: AppLifecycleEventReceipt?

    init(
        privateForegroundRefresh: @escaping PrivateForegroundRefresh = AppLifecycleEventForwarder
            .refreshPrivateForegroundRuntime
    ) {
        self.privateForegroundRefresh = privateForegroundRefresh
    }

    @discardableResult
    func forward(
        event: AppLifecycleEvent,
        runtimeContext: AppFeatureRuntimeContext?
    ) -> AppLifecycleEventReceipt {
        nextSequence &+= 1
        if nextSequence == 0 {
            nextSequence = 1
        }
        let receipt = AppLifecycleEventReceipt(
            event: event,
            sequence: nextSequence,
            runtimeContext: runtimeContext
        )
        latestReceipt = receipt
        NotificationCenter.default.post(
            name: .djAppLifecycleEventForwarded,
            object: nil,
            userInfo: AppLifecycleEventNotification.userInfo(for: receipt)
        )

        guard receipt.canRunPrivateForegroundRefresh,
              let runtimeContext,
              AccountLeaseRuntime.shared.validate(
                  runtimeContext.accountLease,
                  at: .runtime
              ).allowed else {
            return receipt
        }
        privateForegroundRefresh(runtimeContext)
        return receipt
    }

    private static func refreshPrivateForegroundRuntime(
        runtimeContext: AppFeatureRuntimeContext
    ) {
        FamilyRepository.shared.bootstrapCurrentUserFromBackend { _ in
            guard AccountLeaseRuntime.shared.validate(
                runtimeContext.accountLease,
                at: .commit
            ).allowed else {
                return
            }
            KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(
                reason: "foregroundAfterFamilyRefresh"
            )
        }
    }
}

@MainActor
final class AppFeatureFactory {
    func makeTabCoordinator(runtimeContext: AppFeatureRuntimeContext) -> TabCoordinator {
        TabCoordinator(runtimeContext: runtimeContext, featureFactory: self)
    }

    func makeArchiveNavigationController(
        runtimeContext: AppFeatureRuntimeContext
    ) -> UINavigationController {
        makeNavigationController(
            rootViewController: MemoryArchiveViewController(),
            runtimeContext: runtimeContext
        )
    }

    func makeEchoNavigationController(
        runtimeContext: AppFeatureRuntimeContext
    ) -> UINavigationController {
        makeNavigationController(
            rootViewController: EchoViewController(),
            runtimeContext: runtimeContext
        )
    }

    func makeProfileNavigationController(
        runtimeContext: AppFeatureRuntimeContext,
        didRequestLogout: @escaping () -> Void
    ) -> UINavigationController {
        let profileViewController = ProfileViewController()
        profileViewController.didRequestLogout = didRequestLogout
        return makeNavigationController(
            rootViewController: profileViewController,
            runtimeContext: runtimeContext
        )
    }

    private func makeNavigationController(
        rootViewController: UIViewController,
        runtimeContext: AppFeatureRuntimeContext
    ) -> UINavigationController {
        precondition(
            runtimeContext.lifecycleGeneration == runtimeContext.accountLease.generation,
            "Feature construction must retain the active account lifecycle generation"
        )
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.tintColor = DJDesignTokens.Color.textPrimary
        return navigationController
    }
}
