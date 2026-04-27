// Models.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
// All core data models for the app.
// These are plain Swift structs — no CoreData, no Realm.
// Codable lets us encode/decode to JSON (useful for disk caching).

import Foundation

// MARK: - Risk Level

/// The three possible burnout risk tiers surfaced to the clinician.
/// RawValue is String so we can display it directly in the UI.
enum RiskLevel: String, Codable {
    case low      = "Low"
    case moderate = "Moderate"
    case high     = "High"

    /// Color name in Assets.xcassets — avoids hardcoding hex values in UI code.
    var colorName: String {
        switch self {
        case .low:      return "RiskLow"
        case .moderate: return "RiskModerate"
        case .high:     return "RiskHigh"
        }
    }

    /// SF Symbol name used next to the risk label.
    var iconName: String {
        switch self {
        case .low:      return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "xmark.octagon.fill"
        }
    }
}

// MARK: - Burnout Risk Score

/// The output produced by our Core ML model after inference.
/// score: 0.0 – 1.0 (raw probability from the model)
/// level: bucketed label derived from score
/// date:  when the inference was run
struct BurnoutRiskScore: Codable, Hashable {
    let score: Double       // e.g. 0.73
    let level: RiskLevel    // e.g. .high
    let date: Date

    /// Converts the raw 0–1 score to a human-readable percentage string.
    var percentageString: String {
        return "\(Int(score * 100))%"
    }
}

// MARK: - Daily Health Snapshot

/// One day's worth of behavioral data that feeds the burnout model.
struct DailyHealthSnapshot: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let sleepHours: Double      // Hours slept (e.g. 6.5)
    let stepCount: Int          // Steps taken (e.g. 4200)
    let activeMinutes: Int      // Minutes of movement above resting HR (e.g. 22)
    let heartRateVariability: Double  // HRV in ms — lower = more stressed (e.g. 38.0)
    let workHours: Double       // Self-reported or mocked shift hours (e.g. 10.5)
}

// MARK: - Weekly Behavioral Features

/// Aggregated weekly stats fed into the Core ML model as a feature vector.
/// Core ML models take a fixed-size numeric input — this struct represents that input.
struct WeeklyBehavioralFeatures: Codable {
    let avgSleepHours: Double
    let avgStepCount: Double
    let avgActiveMinutes: Double
    let avgHRV: Double
    let avgWorkHours: Double
    let sleepDeficitDays: Int   // Days where sleep < 6 hrs — a key burnout predictor
    let highWorkloadDays: Int   // Days where work > 10 hrs

    /// Derives the feature vector directly from a snapshot array.
    ///
    /// Centralising this here means the Dashboard and Insights ViewModels both
    /// operate on the *same* fetch result, so sparklines and weekly averages are
    /// guaranteed to reflect identical underlying data.
    static func compute(from snapshots: [DailyHealthSnapshot]) -> WeeklyBehavioralFeatures {
        guard !snapshots.isEmpty else {
            return WeeklyBehavioralFeatures(
                avgSleepHours: 0, avgStepCount: 0, avgActiveMinutes: 0,
                avgHRV: 0, avgWorkHours: 0, sleepDeficitDays: 0, highWorkloadDays: 0
            )
        }
        let n = Double(snapshots.count)
        return WeeklyBehavioralFeatures(
            avgSleepHours:    snapshots.map(\.sleepHours).reduce(0, +) / n,
            avgStepCount:     snapshots.map { Double($0.stepCount) }.reduce(0, +) / n,
            avgActiveMinutes: snapshots.map { Double($0.activeMinutes) }.reduce(0, +) / n,
            avgHRV:           snapshots.map(\.heartRateVariability).reduce(0, +) / n,
            avgWorkHours:     snapshots.map(\.workHours).reduce(0, +) / n,
            sleepDeficitDays: snapshots.filter { $0.sleepHours < 6.0 }.count,
            highWorkloadDays: snapshots.filter { $0.workHours > 10.0 }.count
        )
    }
}

// MARK: - Health Insight

/// A text-based recommendation card shown on the dashboard.
/// Generated from behavioral patterns, not from the ML model directly.
nonisolated struct HealthInsight: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String       // Short headline (e.g. "Sleep debt detected")
    let body: String        // 1–2 sentence explanation
    let iconName: String    // SF Symbol name
    let priority: Int       // Lower = shown first (1 is highest priority)
}

// MARK: - Clinician Profile
struct ClinicianProfile: Codable {
    let id: UUID
    let name: String
    let role: String
    let interests: String
    let avatarInitials: String  // e.g. "VB" — used if no photo available
}

// MARK: - Collection View Section Identifiers
// Defined here (not inside ViewControllers) so they are NOT in a @MainActor context.
// UIViewController files inherit @MainActor isolation, which causes the compiler to
// treat protocol conformances (like Hashable) as main actor-isolated — breaking
// the Sendable requirement on UICollectionViewDiffableDataSource's generic constraints.

nonisolated enum InsightsSection: Hashable, Sendable { case main }
