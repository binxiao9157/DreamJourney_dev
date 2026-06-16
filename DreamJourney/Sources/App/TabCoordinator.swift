import UIKit

// MARK: - TabCoordinator：PRD 3-Tab 主界面
final class TabCoordinator: Coordinator {

    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    var didRequestLogout: (() -> Void)?

    let tabBarController = WarmTabBarController()

    init() {
        self.navigationController = UINavigationController()
    }

    func start() {
        setupTabs()
        configureAppearance()
    }

    private func setupTabs() {
        let archiveNav = UINavigationController(rootViewController: MemoryArchiveViewController())
        archiveNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

        let echoNav = UINavigationController(rootViewController: EchoViewController())
        echoNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

        let profileVC = ProfileViewController()
        profileVC.didRequestLogout = { [weak self] in
            self?.didRequestLogout?()
        }
        let profileNav = UINavigationController(rootViewController: profileVC)
        profileNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

        tabBarController.viewControllers = [archiveNav, echoNav, profileNav]
        tabBarController.selectedIndex = 1
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = DJDesignTokens.Color.background
        navAppearance.titleTextAttributes = [
            .foregroundColor: DJDesignTokens.Color.textPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = DJDesignTokens.Color.textPrimary
    }
}
