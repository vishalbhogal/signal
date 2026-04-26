//
//  SceneDelegate.swift
//  Signal
//
//  Created by Vishal Bhogal on 24/04/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // AppCoordinator is retained here as a property.
    // If it were a local variable inside scene(_:willConnectTo:),
    // Swift's ARC would deallocate it at the end of that function — crashing the app.
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        // UIWindowScene is the concrete type for visible screen scenes.
        // Guard unwrap protects against non-window scenes (e.g. CarPlay).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Hand the window to the coordinator and let it drive the entire app.
        let coordinator = AppCoordinator(window: window)
        self.appCoordinator = coordinator
        coordinator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}

