//
//  SceneDelegate.swift
//  DreamJourney
//

import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        let coordinator = AppCoordinator(window: window)
        appCoordinator = coordinator
        coordinator.start()
        if let notificationResponse = connectionOptions.notificationResponse,
           TimeMailboxNotificationScheduler.isDeliveryNotification(userInfo: notificationResponse.notification.request.content.userInfo) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .djTimeMailboxDeliveryNotificationReceived,
                    object: notificationResponse.notification.request.content.userInfo[TimeMailboxNotificationScheduler.deliveryLetterIDUserInfoKey] as? String
                )
            }
        }
        if let url = connectionOptions.urlContexts.first?.url {
            FamilyInvitationDeepLinkService.handle(url: url)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        FamilyInvitationDeepLinkService.handle(url: url)
    }
}
