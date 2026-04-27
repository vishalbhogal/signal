// HealthDataService.swift
// Signal
//
// Created by Vishal Bhogal on 27/04/26.


import Foundation

// MARK: - Protocol
// Protocol-driven service layer for health data.
// later - a LiveHealthDataService
// (Dependency Inversion Principle)

protocol HealthDataServiceProtocol {
    func fetchWeeklySnapshots() async throws -> [DailyHealthSnapshot]
    func fetchProfile() async throws -> ClinicianProfile
}

// MARK: - Mock Implementation
final class MockHealthDataService: HealthDataServiceProtocol {
    /// Returns the last 7 days of snapshots, newest first.
    func fetchWeeklySnapshots() async throws -> [DailyHealthSnapshot] {
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DailyHealthSnapshot(
                id: UUID(),
                date: date,
                sleepHours: Double.random(in: 4.5...8.0),
                stepCount: Int.random(in: 2000...9000),
                activeMinutes: Int.random(in: 10...60),
                heartRateVariability: Double.random(in: 22...65),
                workHours: Double.random(in: 8.0...13.0)
            )
        }
    }

    func fetchProfile() async throws -> ClinicianProfile {
        return ClinicianProfile(
            id: UUID(),
            name: "Vishal Bhogal",
            role: "Teacher",
            interests: "F1, Manchester united, Hiking",
            avatarInitials: "VB"
        )
    }
}

// MARK: - Insight Generator

/// Produces HealthInsight cards by applying rules to the weekly features.
/// This is a pure function — same input always gives same output (deterministic).
struct InsightGenerator {

    static func generateInsights(from features: WeeklyBehavioralFeatures) -> [HealthInsight] {
        var insights: [HealthInsight] = []

        // Rule 1: Sleep deficit
        if features.sleepDeficitDays >= 3 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Sleep debt detected",
                body: "You've slept under 6 hours on \(features.sleepDeficitDays) of the last 7 days. Chronic sleep debt significantly elevates burnout risk.",
                iconName: "moon.zzz.fill",
                priority: 1
            ))
        }

        // Rule 2: Low HRV — a physiological stress marker
        if features.avgHRV < 35 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Low heart rate variability",
                body: "Your average HRV this week is \(Int(features.avgHRV)) ms, below the healthy threshold of 35 ms. This often signals accumulated physiological stress.",
                iconName: "waveform.path.ecg",
                priority: 2
            ))
        }

        // Rule 3: Overwork pattern
        if features.highWorkloadDays >= 4 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Extended work hours pattern",
                body: "You worked over 10 hours on \(features.highWorkloadDays) days this week. Sustained overwork is a leading predictor of clinical burnout.",
                iconName: "clock.badge.exclamationmark.fill",
                priority: 3
            ))
        }

        // Rule 4: Low activity
        if features.avgStepCount < 4000 {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Low physical activity",
                body: "Your average step count is \(Int(features.avgStepCount)) — well below the recommended 7,500. Even short walks reduce cortisol levels.",
                iconName: "figure.walk",
                priority: 4
            ))
        }

        // Always show a positive if no major flags — prevents doom-scrolling.
        if insights.isEmpty {
            insights.append(HealthInsight(
                id: UUID(),
                title: "Looking good this week",
                body: "Your behavioral patterns are within healthy ranges. Keep maintaining your current routine.",
                iconName: "star.fill",
                priority: 1
            ))
        }

        // Sort by priority so most critical insight shows first.
        return insights.sorted { $0.priority < $1.priority }
    }
}
