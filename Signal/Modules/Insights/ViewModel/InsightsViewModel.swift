// InsightsViewModel.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.

import Foundation
import Combine

enum InsightsState {
    case idle
    case loading
    case loaded([HealthInsight])
    case error(String)
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var state: InsightsState = .idle

    private let healthService: HealthDataServiceProtocol

    init(healthService: HealthDataServiceProtocol) {
        self.healthService = healthService
    }

    func loadData() {
        state = .loading
        Task {
            do {
                let snapshots = try await healthService.fetchWeeklySnapshots()
                let features  = WeeklyBehavioralFeatures.compute(from: snapshots)
                let insights  = InsightGenerator.generateInsights(from: features)
                state = .loaded(insights)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
