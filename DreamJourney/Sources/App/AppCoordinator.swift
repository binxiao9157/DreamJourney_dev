import UIKit

// MARK: - AppCoordinator：根协调器，路由到 Auth 或 Tab
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
    private var rootMode: RootMode = .unresolved
    private var startupValidationGeneration = 0

    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
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

        if UserManager.shared.canEnterPrivateUI {
            showMainTab()
        } else if UserManager.shared.requiresPrivateAccessValidation {
            validateCachedPrivateAccess()
        } else {
            showAuth()
        }
    }

    func showAuth() {
        guard rootMode != .auth else { return }
        rootMode = .auth
        childCoordinators.removeAll()
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.didFinishLogin = { [weak self] in
            self?.removeChild(authCoordinator)
            self?.showMainTab()
        }
        addChild(authCoordinator)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        authCoordinator.start()
    }

    func showMainTab() {
        guard UserManager.shared.canEnterPrivateUI, rootMode != .main else { return }
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
        transitionToAuth()
    }

    @objc private func handlePrivateAccessSuspended() {
        transitionToAuth()
    }

    private func validateCachedPrivateAccess() {
        rootMode = .validating
        startupValidationGeneration += 1
        let generation = startupValidationGeneration
        showStartupValidationGate()
        DreamJourneyBackendClient.shared.resumePrivateAccessSession { [weak self] validated in
            guard let self, generation == self.startupValidationGeneration else { return }
            if validated, UserManager.shared.canEnterPrivateUI {
                self.showMainTab()
            } else {
                self.transitionToAuth()
            }
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
        startupValidationGeneration += 1
        childCoordinators.removeAll()
        navigationController = UINavigationController()
        rootMode = .unresolved
        showAuth()
    }
}
