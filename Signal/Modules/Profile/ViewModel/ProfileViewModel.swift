// ProfileViewModel.swift
// Signal

import Foundation
import Combine

enum ProfileState {
    case idle
    case loading
    case loaded(ClinicianProfile)
    case error(String)
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var state: ProfileState = .idle

    private let healthService: HealthDataServiceProtocol

    init(healthService: HealthDataServiceProtocol) {
        self.healthService = healthService
    }

    func loadData() {
        state = .loading
        Task {
            do {
                let profile = try await healthService.fetchProfile()
                state = .loaded(profile)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
