import UIKit

// MARK: - TabCoordinator：PRD 3-Tab 主界面
final class TabCoordinator: Coordinator {

    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    var didRequestLogout: (() -> Void)?

    let tabBarController = WarmTabBarController()
    private let runtimeContext: AppFeatureRuntimeContext
    private let featureFactory: AppFeatureFactory

    init(
        runtimeContext: AppFeatureRuntimeContext,
        featureFactory: AppFeatureFactory
    ) {
        self.runtimeContext = runtimeContext
        self.featureFactory = featureFactory
        self.navigationController = UINavigationController()
    }

    func start() {
        setupTabs()
        configureAppearance()
    }

    private func setupTabs() {
        let archiveNav = featureFactory.makeArchiveNavigationController(
            runtimeContext: runtimeContext
        )
        let echoNav = featureFactory.makeEchoNavigationController(
            runtimeContext: runtimeContext
        )
        let profileNav = featureFactory.makeProfileNavigationController(
            runtimeContext: runtimeContext,
            didRequestLogout: { [weak self] in
                self?.didRequestLogout?()
            }
        )

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
