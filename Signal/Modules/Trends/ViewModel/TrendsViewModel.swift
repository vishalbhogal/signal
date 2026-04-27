// TrendsViewModel.swift
// Signal
//
//  Created by Vishal Bhogal on 27/04/26.
//
//

import Foundation
import Combine

enum TrendsState {
    case idle
    case loading
    case loaded([DailyHealthSnapshot])
    case error(String)
}

@MainActor
final class TrendsViewModel: ObservableObject {
    @Published private(set) var state: TrendsState = .idle

    private let healthService: HealthDataServiceProtocol

    init(healthService: HealthDataServiceProtocol) {
        self.healthService = healthService
    }

    func loadData() {
        state = .loading
        Task {
            do {
                let snapshots = try await healthService.fetchWeeklySnapshots()
                state = .loaded(snapshots.sorted { $0.date < $1.date })
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
