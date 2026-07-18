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
    private var rootMode: RootMode = .unresolved
    private var accountSessionReceipt: AccountSessionTransitionReceipt?
    private var accountSessionTask: Task<Void, Never>?

    init(
        window: UIWindow,
        accountSessionActor: AccountSessionActor = .shared,
        appComposition: AppComposition? = nil
    ) {
        self.window = window
        self.accountSessionActor = accountSessionActor
        self.appComposition = appComposition ?? AppComposition()
        self.navigationController = UINavigationController()
    }

    deinit {
        accountSessionTask?.cancel()
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

        bootstrapAccountSession()
    }

    func showAuth() {
        guard rootMode != .auth else { return }
        rootMode = .auth
        childCoordinators.removeAll()
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
        tabCoordinator.didRequestLogout = { [weak self] in
            self?.removeChild(tabCoordinator)
            self?.navigationController = UINavigationController()
            self?.showAuth()
        }
        addChild(tabCoordinator)
        window?.rootViewController = tabCoordinator.tabBarController
        window?.makeKeyAndVisible()
        tabCoordinator.start()
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

    private func activateVerifiedLogin() {
        guard let credential = UserManager.shared.accountSessionCredentialSnapshot(),
              credential.trust == .requiresOnlineValidation,
              credential.normalizedSubjectId == UserManager.shared.currentUser?.id else {
            transitionToAuth()
            return
        }
        rootMode = .validating
        showStartupValidationGate()
        accountSessionTask?.cancel()
        accountSessionTask = Task { [weak self, accountSessionActor] in
            let receipt = await accountSessionActor.activateVerifiedLogin(credential)
            guard !Task.isCancelled, let self else { return }
            self.accountSessionTask = nil
            self.accountSessionReceipt = receipt.accepted ? receipt : nil
            if receipt.accepted, receipt.rootRoute == .privateUI {
                self.showMainTab()
            } else {
                self.transitionToAuth()
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
        navigationController = UINavigationController()
        rootMode = .unresolved
        showAuth()
    }
}

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
        return featureFactory.makeTabCoordinator(runtimeContext: runtimeContext)
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
