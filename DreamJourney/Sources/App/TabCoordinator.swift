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

    /// A validated notification/deeplink may only select a neutral destination.
    /// Resource opening, read/archive mutations, and any Voice/Digital Human
    /// runtime activation remain explicit user actions inside their feature.
    @discardableResult
    func selectNotificationRuntimeRoute(
        _ route: NotificationRuntimeRoute,
        runtimeContext: AppFeatureRuntimeContext
    ) -> Bool {
        guard route.accountLease == runtimeContext.accountLease,
              AccountLeaseRuntime.shared.validate(
                  runtimeContext.accountLease,
                  at: .ui
              ).allowed else {
            return false
        }
        let maximumIndex = max((tabBarController.viewControllers?.count ?? 1) - 1, 0)
        tabBarController.selectedIndex = min(route.payload.kind.selectedTabIndex, maximumIndex)
        return true
    }

    /// Routes an already policy-approved invitation into the controlled
    /// Profile area. It never adds a fourth tab or falls back to private chat.
    @discardableResult
    func selectPublicationVisitor(
        runtime: PublicationVisitorRuntime,
        runtimeContext: AppFeatureRuntimeContext
    ) -> Bool {
        guard runtime.hasPendingOrActiveAccess,
              runtimeContext.accountLease == self.runtimeContext.accountLease,
              AccountLeaseRuntime.shared.validate(runtimeContext.accountLease, at: .ui).allowed,
              PublicationVisitorAccessGate.isRouteAllowed,
              let viewControllers = tabBarController.viewControllers,
              viewControllers.indices.contains(2),
              let profileNavigationController = viewControllers[2] as? UINavigationController else {
            return false
        }
        tabBarController.selectedIndex = 2
        if profileNavigationController.topViewController is ProfilePublicationVisitorViewController {
            return true
        }
        profileNavigationController.pushViewController(
            ProfilePublicationVisitorViewController(runtime: runtime),
            animated: true
        )
        return true
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
