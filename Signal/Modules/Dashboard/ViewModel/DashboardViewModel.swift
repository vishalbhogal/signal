// DashboardViewModel.swift
// Signal
//
// ─────────────────────────────────────────────────────────────────────────────
// COMBINE — WHY IT'S USED HERE
// ─────────────────────────────────────────────────────────────────────────────
//
// Combine is Apple's reactive framework. Instead of the ViewController
// asking "what's the data right now?", it *subscribes* to publishers
// on the ViewModel and is automatically notified when data changes.
//
// Key concepts used below:
//
//   @Published var x: T
//     Creates a Publisher that emits a new value every time `x` is set.
//     The ViewController subscribes to $x (the projected value).
//
//   AnyCancellable
//     A token returned by .sink() or .assign(). As long as you hold it,
//     the subscription stays alive. When it's deallocated, the subscription
//     is cancelled — preventing zombie subscriptions.
//
//   .receive(on: DispatchQueue.main)
//     Ensures UI updates happen on the main thread, because UIKit is not
//     thread-safe. Async work runs on background threads; this hops back.
//
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Combine  // Apple's reactive framework (no package needed — built into iOS 13+)

// MARK: - Dashboard State

/// Represents every possible state of the dashboard screen.
/// The VC switches on this enum to decide what to show.
enum DashboardState {
    case idle                   // App just launched, nothing loaded yet
    case loading                // Async fetch is in progress
    case loaded(DashboardData)  // Data is ready — pass it as associated value
    case error(String)          // Something went wrong — show error message
}

/// All the data the Dashboard screen needs, bundled together.
/// Passing one struct is cleaner than many separate @Published properties.
struct DashboardData {
    let riskScore: BurnoutRiskScore
    let snapshots: [DailyHealthSnapshot]
    let insights: [HealthInsight]
    let features: WeeklyBehavioralFeatures
}

// MARK: - ViewModel

/// Owns all business logic for the Dashboard screen.
/// The ViewController only reads from this — it never fetches or processes data itself.
@MainActor  // Ensures all @Published mutations happen on the main thread automatically
final class DashboardViewModel: ObservableObject {

    // MARK: Published State

    /// The VC subscribes to $state and reacts to every change.
    /// `private(set)` means only this class can write — VC can only read.
    @Published private(set) var state: DashboardState = .idle

    // MARK: Dependencies

    private let healthService: HealthDataServiceProtocol
    private let riskEngine: BurnoutRiskEngineProtocol

    // MARK: Init

    init(healthService: HealthDataServiceProtocol,
         riskEngine: BurnoutRiskEngineProtocol) {
        self.healthService = healthService
        self.riskEngine = riskEngine
    }

    // MARK: - Data Loading

    /// Called by the ViewController in viewDidLoad or on pull-to-refresh.
    func loadData() {
        state = .loading

        // Task { } creates a new async context from a sync context.
        // Without Task, you can't call `await` inside a regular function.
        Task {
            do {
                // Run both fetches concurrently using async let.
                // Without `async let`, they'd run sequentially (slower).
                // With `async let`, both start immediately and we wait for both.
                async let snapshots = healthService.fetchWeeklySnapshots()
                async let features  = healthService.fetchWeeklyFeatures()

                // `await` here waits for BOTH to finish before continuing.
                let (resolvedSnapshots, resolvedFeatures) = try await (snapshots, features)

                // Run Core ML inference with the aggregated weekly features.
                let riskScore = try await riskEngine.predict(features: resolvedFeatures)

                // Generate text insight cards from the same features.
                let insights = InsightGenerator.generateInsights(from: resolvedFeatures)

                // Bundle everything and publish the loaded state.
                // Because we're @MainActor, this is safe to do directly.
                state = .loaded(DashboardData(
                    riskScore: riskScore,
                    snapshots: resolvedSnapshots,
                    insights: insights,
                    features: resolvedFeatures
                ))

            } catch {
                // Any thrown error lands here — network, decoding, or ML errors.
                state = .error(error.localizedDescription)
            }
        }
    }
}
