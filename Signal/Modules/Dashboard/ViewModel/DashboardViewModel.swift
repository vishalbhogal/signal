// DashboardViewModel.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
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
import Combine
import UIKit   // StatItem carries UIColor — acceptable for UIKit-backed ViewModels

// MARK: - Stat Item
//
// Represents one "This Week" metric chip on the dashboard.
// Lives here (not in the ViewController) because `buildStatItems(from:)` is
// a data-transformation step that should be unit-testable without a live VC.
//
// Note: UIColor in a ViewModel is a pragmatic trade-off in UIKit apps.
// In a cross-platform / SwiftUI architecture you'd use a semantic color key
// and resolve it to UIColor in the cell.
struct StatItem: Sendable {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let bubbleColor: UIColor        // Pastel bubble behind the icon
    let iconColor: UIColor          // Darker tint for the icon itself
    let sparklineValues: [Double]   // 7 daily values for the mini sparkline
}

extension StatItem: Hashable {
    static func == (lhs: StatItem, rhs: StatItem) -> Bool {
        lhs.title == rhs.title && lhs.value == rhs.value && lhs.unit == rhs.unit
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(value)
        hasher.combine(unit)
    }
}

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
    // Pre-built by the ViewModel so the VC only needs to hand them to the data source.
    let statItems: [StatItem]
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
                // Fetch the raw daily snapshots — single source of truth.
                // Features are then *derived* from this same array so sparklines
                // and weekly averages are guaranteed to reflect identical data.
                // (Previously fetchWeeklyFeatures() was called concurrently and
                //  generated its own independent random dataset — a subtle bug.)
                let snapshots = try await healthService.fetchWeeklySnapshots()
                let features  = WeeklyBehavioralFeatures.compute(from: snapshots)

                // Run Core ML inference with the aggregated weekly features.
                let riskScore = try await riskEngine.predict(features: features)

                // Generate text insight cards from the same features.
                let insights = InsightGenerator.generateInsights(from: features)

                // Build stat chip view-models here, not in the ViewController,
                // so this transformation is covered by unit tests.
                let statItems = Self.buildStatItems(from: features, snapshots: snapshots)

                // Bundle everything and publish the loaded state.
                // Because we're @MainActor, this is safe to do directly.
                state = .loaded(DashboardData(
                    riskScore: riskScore,
                    snapshots: snapshots,
                    insights: insights,
                    features: features,
                    statItems: statItems
                ))

            } catch {
                // Any thrown error lands here — network, decoding, or ML errors.
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Stat Item Builder

    /// Transforms raw health data into the view-model structs consumed by StatCell.
    /// `static` so it can be called directly in unit tests without a ViewModel instance.
    static func buildStatItems(from features: WeeklyBehavioralFeatures,
                               snapshots: [DailyHealthSnapshot]) -> [StatItem] {
        // Sort oldest → newest so the sparkline reads left-to-right in time.
        let sorted = snapshots.sorted { $0.date < $1.date }
        return [
            StatItem(
                title: "Sleep",
                value: String(format: "%.1f", features.avgSleepHours),
                unit: "hrs",
                iconName: "moon.fill",
                bubbleColor: Signal.Colors.sleepBubble,
                iconColor:   Signal.Colors.sleepIcon,
                sparklineValues: sorted.map { $0.sleepHours }
            ),
            StatItem(
                title: "Steps",
                value: "\(Int(features.avgStepCount))",
                unit: "avg",
                iconName: "figure.walk",
                bubbleColor: Signal.Colors.stepsBubble,
                iconColor:   Signal.Colors.stepsIcon,
                sparklineValues: sorted.map { Double($0.stepCount) / 1000 }
            ),
            StatItem(
                title: "HRV",
                value: "\(Int(features.avgHRV))",
                unit: "ms",
                iconName: "waveform.path.ecg",
                bubbleColor: Signal.Colors.hrvBubble,
                iconColor:   Signal.Colors.hrvIcon,
                sparklineValues: sorted.map { $0.heartRateVariability }
            ),
            StatItem(
                title: "Shift",
                value: String(format: "%.1f", features.avgWorkHours),
                unit: "hrs",
                iconName: "briefcase.fill",
                bubbleColor: Signal.Colors.workBubble,
                iconColor:   Signal.Colors.workIcon,
                sparklineValues: sorted.map { $0.workHours }
            )
        ]
    }
}
