// InsightsViewModel.swift
// Signal

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
                let features = try await healthService.fetchWeeklyFeatures()
                let insights = InsightGenerator.generateInsights(from: features)
                state = .loaded(insights)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
