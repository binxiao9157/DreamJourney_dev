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
        let coordinator = AppCoordinator(window: window)
        appCoordinator = coordinator
        coordinator.start()
        coordinator.handleSceneLifecycleEvent(.sceneConnected)
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
