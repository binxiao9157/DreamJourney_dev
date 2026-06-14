import UIKit

// MARK: - TabCoordinator：主界面
final class TabCoordinator: Coordinator {

    var navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    var didRequestLogout: (() -> Void)?

    let tabBarController = WarmTabBarController()
    private var familyInvitationObserver: NSObjectProtocol?
    private var timeMailboxNotificationObserver: NSObjectProtocol?

    init() {
        self.navigationController = UINavigationController()
    }

    deinit {
        if let familyInvitationObserver {
            NotificationCenter.default.removeObserver(familyInvitationObserver)
        }
        if let timeMailboxNotificationObserver {
            NotificationCenter.default.removeObserver(timeMailboxNotificationObserver)
        }
    }

    func start() {
        setupTabs()
        configureAppearance()
        KBLiteManager.shared.bootstrapFromBackendIfNeeded()
        familyInvitationObserver = NotificationCenter.default.addObserver(
            forName: .djFamilyInvitationDeepLinkReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFamilyInvitationDeepLinkNotification(notification)
        }
        timeMailboxNotificationObserver = NotificationCenter.default.addObserver(
            forName: .djTimeMailboxDeliveryNotificationReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let letterID = notification.object as? String
            self?.openTimeMailboxFromNotification(letterID: letterID)
        }
        DispatchQueue.main.async { [weak self] in
            self?.consumePendingFamilyInvitationDeepLink()
        }
    }

    private func setupTabs() {
        // Tab1: 对话记录
        let homeNav = UINavigationController()
        let homeVC = AIRecordingViewController()
        homeVC.title = "对话记录"
        homeNav.viewControllers = [homeVC]
        homeNav.navigationBar.tintColor = .warmPrimary

        // Tab2: 寻梦环游足迹（主态）
        let mapNav = UINavigationController()
        let currentUserId = UserManager.shared.currentUser?.id ?? ""
        let mapVC = MapFootprintViewController(viewMode: .host, ownerId: currentUserId)
        mapVC.title = "寻梦环游足迹"
        mapNav.viewControllers = [mapVC]
        mapNav.navigationBar.tintColor = .warmPrimary

        // Tab3: 亲属圈
        let familyNav = UINavigationController()
        let familyVC = FamilyCircleViewController()
        familyVC.title = "亲属圈"
        familyNav.viewControllers = [familyVC]
        familyNav.navigationBar.tintColor = .warmPrimary

        // 注入退出登录回调
        familyVC.didRequestLogout = { [weak self] in
            self?.didRequestLogout?()
        }

        // Tab4: 时空信箱
        let mailboxNav = UINavigationController()
        let mailboxVC = TimeMailboxViewController()
        mailboxVC.title = "时空信箱"
        mailboxNav.viewControllers = [mailboxVC]
        mailboxNav.navigationBar.tintColor = .warmPrimary

        // Tab5: 记忆档案馆
        let archiveNav = UINavigationController()
        let archiveVC = MemoryArchiveViewController()
        archiveVC.title = "记忆档案馆"
        archiveNav.viewControllers = [archiveVC]
        archiveNav.navigationBar.tintColor = .warmPrimary

        tabBarController.viewControllers = [homeNav, mapNav, familyNav, mailboxNav, archiveNav]
    }

    private func configureAppearance() {
        // Warm Vintage: 使用自定义 WarmTabBarController，系统 appearance 已无需配置
        // NavigationBar 全局样式：深棕色标题
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .warmBackground
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.warmPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .warmPrimary
    }

    private func handleFamilyInvitationDeepLinkNotification(_ notification: Notification) {
        if let code = notification.object as? String {
            openFamilyInvitation(code: code)
        } else {
            consumePendingFamilyInvitationDeepLink()
        }
    }

    private func consumePendingFamilyInvitationDeepLink() {
        guard let code = FamilyInvitationDeepLinkService.consumePendingInvitationCode() else {
            return
        }
        openFamilyInvitation(code: code)
    }

    private func openFamilyInvitation(code: String) {
        tabBarController.selectedIndex = 2
        guard let familyNav = tabBarController.viewControllers?.dropFirst(2).first as? UINavigationController,
              let familyVC = familyNav.viewControllers.first as? FamilyCircleViewController else {
            return
        }
        familyVC.acceptInvitationCodeFromDeepLink(code)
    }

    private func openTimeMailboxFromNotification(letterID: String?) {
        tabBarController.selectedIndex = 3
        guard let mailboxNav = tabBarController.viewControllers?.dropFirst(3).first as? UINavigationController,
              let mailboxVC = mailboxNav.viewControllers.first as? TimeMailboxViewController else {
            return
        }
        mailboxNav.popToRootViewController(animated: false)
        mailboxVC.openLetterFromNotification(id: letterID)
    }
}
