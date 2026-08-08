//
//  SceneDelegate.swift
//  DreamJourney
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        let appComposition = (UIApplication.shared.delegate as? AppDelegate)?.appComposition
        let coordinator = AppCoordinator(window: window, appComposition: appComposition)
        appCoordinator = coordinator
        coordinator.start()
        coordinator.handleSceneLifecycleEvent(.sceneConnected)
        if let notificationResponse = connectionOptions.notificationResponse {
            coordinator.receiveNotificationRuntimeRoute(
                userInfo: notificationResponse.notification.request.content.userInfo,
                source: .notificationResponse
            )
        }
        connectionOptions.urlContexts.forEach { context in
            coordinator.receiveAppDeepLink(context.url)
        }
        connectionOptions.userActivities.compactMap(\.webpageURL).forEach { url in
            coordinator.receiveAppDeepLink(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { context in
            appCoordinator?.receiveAppDeepLink(context.url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        appCoordinator?.receiveAppDeepLink(url)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        appCoordinator?.handleSceneLifecycleEvent(.didDisconnect)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        appCoordinator?.handleSceneLifecycleEvent(.didBecomeActive)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        appCoordinator?.handleSceneLifecycleEvent(.willResignActive)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appCoordinator?.handleSceneLifecycleEvent(.willEnterForeground)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        appCoordinator?.handleSceneLifecycleEvent(.didEnterBackground)
    }
}
