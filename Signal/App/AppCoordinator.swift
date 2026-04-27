// AppCoordinator.swift
// Signal
//
// Created by Vishal Bhogal on 27/04/26.


import UIKit

// MARK: - Coordinator Protocol

protocol Coordinator: AnyObject {
    /// Every coordinator must be able to start itself.
    ///   • ViewControllers manage their own view.
    ///   • Navigation logic lives in one place — easy to change flows.
    ///   • Each screen is independently testable without a real nav stack.
    var navigationController: UINavigationController { get }
    func start()
}

// MARK: - App Coordinator

/// The root coordinator. Owns the UIWindow and decides what to show first.
/// Flow: Splash → Main Tab Bar
final class AppCoordinator: Coordinator {
    let window: UIWindow
    let navigationController: UINavigationController
    
    // Passing services in rather than using singletons everywhere
    //  testing easier (inject mocks).
    private let healthService: HealthDataServiceProtocol
    private let riskEngine: BurnoutRiskEngineProtocol
    
    // Shared ExploreManager — one instance for the app's lifetime so that
    // the CLLocationManager delegate and @Published spots are not duplicated.
    private lazy var exploreManager = ExploreManager()
    
    init(window: UIWindow,
         healthService: HealthDataServiceProtocol = MockHealthDataService(),
         riskEngine: BurnoutRiskEngineProtocol = MockBurnoutRiskEngine()) {
        self.window = window
        self.healthService = healthService
        self.riskEngine = riskEngine
        self.navigationController = UINavigationController()
    }
    
    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        showSplash()
    }
    
    // MARK: - Navigation Steps
    
    private func showSplash() {
        let splashVC = SplashViewController()
        splashVC.onAnimationComplete = { [weak self] in
            guard let self else {
                print("self is nil")
                return
            }
            self.showMainTabBar()
        }
        navigationController.setViewControllers([splashVC], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }
    
    private func showMainTabBar() {
        let tabBarController = buildTabBarController()
        UIView.transition(
            with: window,
            duration: 0.4,
            options: .transitionCrossDissolve,
            animations: { self.window.rootViewController = tabBarController }
        )
    }
    
    // MARK: - Tab Bar Assembly
    
    private func buildTabBarController() -> UITabBarController {
        let tabBar = UITabBarController()
        //  nav controllers- each tab have its own navigation stack.
        let dashboardNav = UINavigationController(
            rootViewController: makeDashboardVC()
        )
        let trendsNav = UINavigationController(
            rootViewController: makeTrendsVC()
        )
        let insightsNav = UINavigationController(
            rootViewController: makeInsightsVC()
        )
        let profileNav = UINavigationController(
            rootViewController: makeProfileVC()
        )
        
        dashboardNav.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "heart.text.clipboard"), tag: 0)
        trendsNav.tabBarItem    = UITabBarItem(title: "Trends",    image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 1)
        insightsNav.tabBarItem  = UITabBarItem(title: "Insights",  image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        profileNav.tabBarItem   = UITabBarItem(title: "Profile",   image: UIImage(systemName: "person.crop.circle"), tag: 3)
        UIView.applyTabBarStyling(to: tabBar.tabBar)
        tabBar.viewControllers = [dashboardNav, trendsNav, insightsNav, profileNav]
        return tabBar
    }
    
    // MARK: - VC Factories
    // (with dependencies injected)
    
    private func makeDashboardVC() -> UIViewController {
        let vm = DashboardViewModel(healthService: healthService, riskEngine: riskEngine)
        return DashboardViewController(viewModel: vm, exploreManager: exploreManager)
    }
    
    private func makeTrendsVC() -> UIViewController {
        let vm = TrendsViewModel(healthService: healthService)
        return TrendsViewController(viewModel: vm)
    }
    
    private func makeInsightsVC() -> UIViewController {
        let vm = InsightsViewModel(healthService: healthService)
        return InsightsViewController(viewModel: vm)
    }
    
    private func makeProfileVC() -> UIViewController {
        let vm = ProfileViewModel(healthService: healthService)
        return ProfileViewController(viewModel: vm)
    }
}

