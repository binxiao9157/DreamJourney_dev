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
    private var rootMode: RootMode = .unresolved
    private var accountSessionReceipt: AccountSessionTransitionReceipt?
    private var accountSessionTask: Task<Void, Never>?

    init(window: UIWindow, accountSessionActor: AccountSessionActor = .shared) {
        self.window = window
        self.accountSessionActor = accountSessionActor
        self.navigationController = UINavigationController()
    }

    deinit {
        accountSessionTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
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
              rootMode != .main else {
            return
        }
        rootMode = .main
        childCoordinators.removeAll()
        let tabCoordinator = TabCoordinator()
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
        let expectedGeneration = accountSessionReceipt?.generation
        accountSessionTask?.cancel()
        accountSessionReceipt = nil
        Task { [accountSessionActor] in
            _ = await accountSessionActor.signOut(
                expectedGeneration: expectedGeneration,
                reason: "userLoggedOut"
            )
        }
        transitionToAuth()
    }

    @objc private func handlePrivateAccessSuspended() {
        let expectedGeneration = accountSessionReceipt?.generation
        accountSessionTask?.cancel()
        accountSessionReceipt = nil
        Task { [accountSessionActor] in
            _ = await accountSessionActor.suspend(
                expectedGeneration: expectedGeneration,
                reason: "privateAccessSuspended"
            )
        }
        transitionToAuth()
    }

    private func bootstrapAccountSession() {
        rootMode = .validating
        showStartupValidationGate()
        let cachedSubjectId = UserManager.shared.currentUser?.id
        let credential = UserManager.shared.accountSessionCredentialSnapshot()
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
        accountSessionReceipt = nil
        Task { [accountSessionActor] in
            _ = await accountSessionActor.suspend(
                expectedGeneration: expectedGeneration,
                reason: reason
            )
        }
        transitionToAuth()
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
