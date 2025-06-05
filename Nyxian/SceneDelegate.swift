//
//  SceneDelegate.swift
//  Nyxian
//
//  Created by Assistant on 28.05.25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let tabViewController: UITabBarController = UITabBarController()
        
        let contentViewController: ContentViewController = ContentViewController(path: "\(NSHomeDirectory())/Documents/Projects")
        let settingsViewController: SettingsViewController = SettingsViewController(style: .insetGrouped)
        
        let projectsNavigationController: UINavigationController = UINavigationController(rootViewController: contentViewController)
        let settingsNavigationController: UINavigationController = UINavigationController(rootViewController: settingsViewController)
        
        projectsNavigationController.tabBarItem = UITabBarItem(title: "Projects", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 0)
        settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 1)

        tabViewController.viewControllers = [projectsNavigationController, settingsNavigationController]
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabViewController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}