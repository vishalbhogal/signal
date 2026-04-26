// AppCoordinator.swift
// Signal
//
// ─────────────────────────────────────────────────────────────────────────────
// COORDINATOR PATTERN — WHY IT EXISTS
// ─────────────────────────────────────────────────────────────────────────────
//
// In a standard UIKit app, ViewControllers know about each other —
// DashboardVC pushes TrendsVC, which pushes DetailVC, etc.
// This makes VCs tightly coupled and hard to reuse or test.
//
// The Coordinator pattern fixes this by giving navigation responsibility
// to a dedicated object. ViewControllers don't know what comes next —
// they just call delegate methods or closures, and the Coordinator decides.
//
// Benefits:
//   • ViewControllers become simple: they only manage their own view.
//   • Navigation logic lives in one place — easy to change flows.
//   • Each screen is independently testable without a real nav stack.
// ─────────────────────────────────────────────────────────────────────────────

import UIKit

// MARK: - Coordinator Protocol

/// Every coordinator must be able to start itself.
/// Child coordinators (e.g. a ProfileCoordinator) also conform to this.
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    func start()
}

// MARK: - App Coordinator

/// The root coordinator. Owns the UIWindow and decides what to show first.
/// Flow: Splash → Main Tab Bar
final class AppCoordinator: Coordinator {

    // The window is retained here — if nothing holds it, it deallocates and the UI disappears.
    let window: UIWindow

    // The nav controller is used during the splash phase.
    // After splash, we swap to a UITabBarController.
    let navigationController: UINavigationController

    // Dependency container — one place to create and share services.
    // Passing services in rather than using singletons everywhere
    // makes testing easier (you can inject mocks).
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

    /// Entry point — called from SceneDelegate after the window is ready.
    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        showSplash()
    }

    // MARK: - Navigation Steps

    private func showSplash() {
        let splashVC = SplashViewController()

        // The splash VC calls this closure when its animation finishes.
        // Closures here instead of delegates keeps the code compact.
        splashVC.onAnimationComplete = { [weak self] in
            // `weak self` prevents a retain cycle:
            // AppCoordinator → SplashVC → closure → AppCoordinator (cycle!)
            // With weak, if AppCoordinator is deallocated, self becomes nil safely.
            self?.showMainTabBar()
        }

        // `setViewControllers` replaces the entire nav stack at once.
        // `animated: false` because splash is the very first screen — nothing to animate from.
        navigationController.setViewControllers([splashVC], animated: false)
        navigationController.setNavigationBarHidden(true, animated: false)
    }

    private func showMainTabBar() {
        let tabBarController = buildTabBarController()
        
        // Swap the root VC with a cross-dissolve transition.
        // This is smoother than a push — it looks like the splash "becomes" the app.
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

        // Create each tab's ViewController and wrap it in a UINavigationController.
        // Wrapping in nav controllers lets each tab have its own navigation stack.
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

        // Tab bar items — title + SF Symbol icon.
        dashboardNav.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "heart.text.clipboard"), tag: 0)
        trendsNav.tabBarItem    = UITabBarItem(title: "Trends",    image: UIImage(systemName: "chart.line.uptrend.xyaxis"), tag: 1)
        insightsNav.tabBarItem  = UITabBarItem(title: "Insights",  image: UIImage(systemName: "lightbulb.fill"), tag: 2)
        profileNav.tabBarItem   = UITabBarItem(title: "Profile",   image: UIImage(systemName: "person.crop.circle"), tag: 3)
        applyTabBarStyling(to: tabBar.tabBar)
        tabBar.viewControllers = [dashboardNav, trendsNav, insightsNav, profileNav]
        return tabBar
    }
    
    /// Configures the frosted glass background and custom active/inactive colors
    private func applyTabBarStyling(to tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        
        // 1. Frosted glass background
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.shadowColor = .clear // Removes the harsh top border line
        
        // 2. Colors: Deep green (Active) and Slate (Inactive)
        let activeColor = UIColor(red: 30/255, green: 63/255, blue: 47/255, alpha: 1.0)
        let inactiveColor = UIColor.secondaryLabel
        
        // 3. Normal (Inactive) State
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // 4. Selected (Active) State
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        // 5. Apply to the actual tab bar
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Force the tintColor as a fallback for older components
        tabBar.tintColor = activeColor
    }

    // MARK: - VC Factories
    // Each factory method creates the ViewModel first (with dependencies injected),
    // then passes it to the ViewController. VCs never create their own ViewModels.

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
