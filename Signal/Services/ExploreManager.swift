// ExploreManager.swift
// Signal
//
// Created by Vishal Bhogal on 24/04/26.
// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE NEARBY — SERVICE LAYER
// ─────────────────────────────────────────────────────────────────────────────
//
// ExploreManager does three things:
//   1. Asks CoreLocation for the user's current position.
//   2. Queries MapKit for nearby parks / green spaces / landmarks.
//   3. Tracks which spots the user has already visited (UserDefaults).
//
//
// PROXIMITY STATES
//   .far    — user is > 375 m away   → "Visit" button is disabled (greyed out)
//   .nearby — user is ≤ 375 m away   → "Visit" button active (partial XP)
//   .exact  — user is ≤  75 m away   → "Visit" button active (full XP)
//
// BADGE INTEGRATION
//   markVisited(_:) delegates to BadgeStore.recordParkVisit()
// ─────────────────────────────────────────────────────────────────────────────

import Combine
import CoreLocation
import Foundation
import MapKit

// MARK: - ExploreSpot
struct ExploreSpot: Hashable, Sendable {
    enum ProximityState: Sendable {
        case far
        case nearby
        case exact     
    }
    let id: String
    let name: String
    let categoryName: String
    let symbolName: String
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double
    let prompt: String
    var isVisited: Bool
    var proximityState: ProximityState
    static func == (lhs: ExploreSpot, rhs: ExploreSpot) -> Bool {
        lhs.id == rhs.id &&
        lhs.isVisited == rhs.isVisited &&
        lhs.proximityState == rhs.proximityState
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Human-readable distance string (e.g. "320 m", "1.2 km").
    var distanceString: String {
        Measurement(value: distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}

// MARK: - ExploreManager
 final class ExploreManager: NSObject {
    @Published private(set) var spots: [ExploreSpot] = []
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()
    private let visitedKey = "signal.visitedExploreSpotIDs"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public API
    func requestLocationIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            // In the Simulator the location delegate often never fires unless
            // a custom location is set in Debug > Location.  Fall back to a
            // known urban coordinate so the feature is testable during development.
            #if targetEnvironment(simulator)
            Task {
                // Small delay lets the delegate fire first if a location IS set;
                // if spots are still empty after that, use the fallback.
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s
                if self.spots.isEmpty {
                    // Central London — Regent's Park, British Museum, etc. within range.
                    let fallback = CLLocation(latitude: 51.5074, longitude: -0.1278)
                    await self.refresh(around: fallback)
                }
            }
            #endif
        default:
            break
        }
    }

    /// Fetch nearby spots around a given location and update `spots`.
    func refresh(around userLocation: CLLocation) async {
        var fetched = await fetchSpots(around: userLocation)
        let visited = visitedIDs()
        for i in fetched.indices {
            fetched[i].isVisited = visited.contains(fetched[i].id)
            fetched[i].proximityState = computeProximity(for: fetched[i], userLocation: userLocation)
        }
        var seen = Set<String>()
        fetched = fetched.filter { seen.insert($0.id).inserted }
        spots = fetched
    }

    /// Marks a spot as visited, persists it, increments BadgeStore's counter,
    /// and returns any newly unlocked BadgeDefinitions so the caller can present an alert.
    @discardableResult
    func markVisited(_ spot: ExploreSpot) -> [BadgeDefinition] {
        guard !spot.isVisited else { return [] }

        // Persist the visited spot ID.
        var ids = visitedIDs()
        ids.insert(spot.id)
        UserDefaults.standard.set(Array(ids), forKey: visitedKey)

        // Mirror the change in the in-memory array so the UI updates instantly.
        if let idx = spots.firstIndex(of: spot) {
            spots[idx].isVisited = true
        }

        // Delegate XP / badge logic to BadgeStore — it is the single source of truth.
        return BadgeStore.shared.recordParkVisit()
    }

    // MARK: - Private Helpers

    private func visitedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: visitedKey) ?? [])
    }

    private func computeProximity(for spot: ExploreSpot,
                                  userLocation: CLLocation) -> ExploreSpot.ProximityState {
        let spotLoc = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        let dist = userLocation.distance(from: spotLoc)
        if dist <= 75  { return .exact }
        if dist <= 375 { return .nearby }
        return .far
    }

    // MARK: - MapKit Fetch

    private func fetchSpots(around userLocation: CLLocation) async -> [ExploreSpot] {
        // One spot at a time — each category carries its own mindful prompts.
        let categories: [(cats: [MKPointOfInterestCategory], symbol: String, name: String, prompts: [String])] = [
            (
                [.park],
                "tree.fill",
                "Park",
                ["Notice one color you usually walk past.",
                 "Spend two minutes without looking at a screen.",
                 "Spot something moving naturally — leaves, water, birds."]
            ),
            (
                [.nationalPark],
                "leaf.circle.fill",
                "Green Space",
                ["Take a deep breath when you arrive.",
                 "Find one plant you cannot name.",
                 "Leave your phone in your pocket for two minutes."]
            ),
            (
                [.museum, .theater],
                "building.columns.fill",
                "Landmark",
                ["Find one architectural detail worth remembering.",
                 "Walk slower for the last 100 m.",
                 "Look for a cinematic angle."]
            ),
        ].shuffled()

        // Terms that flag a place as inappropriate for a wellness step-up feature.
        let blocklist = ["hospital", "clinic", "police", "embassy",
                         "consulate", "funeral", "cemetery", "jail", "prison", "detention"]

        var results: [ExploreSpot] = []
        var usedLocations: [CLLocation] = []

        for entry in categories {
            guard results.isEmpty else { break }   // only 1 spot needed

            let request = MKLocalPointsOfInterestRequest(center: userLocation.coordinate, radius: 2000)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: entry.cats)
            guard let response = try? await MKLocalSearch(request: request).start() else { continue }

            let filtered = response.mapItems.filter { item in
                guard let loc = item.placemark.location else { return false }
                let lowercaseName = (item.name ?? "").lowercased()
                guard blocklist.allSatisfy({ !lowercaseName.contains($0) }) else { return false }
                let dist = userLocation.distance(from: loc)
                guard dist >= 80, dist <= 1800 else { return false }
                return usedLocations.allSatisfy { $0.distance(from: loc) > 150 }
            }

            if let item = filtered.first, let loc = item.placemark.location {
                let dist = userLocation.distance(from: loc)
                let lat4 = (loc.coordinate.latitude  * 10_000).rounded() / 10_000
                let lon4 = (loc.coordinate.longitude * 10_000).rounded() / 10_000
                let spotID = "\(lat4),\(lon4)"
                let prompt = entry.prompts.randomElement() ?? "Notice one good thing on the walk."

                let spot = ExploreSpot(
                    id: spotID,
                    name: item.name ?? entry.name,
                    categoryName: entry.name,
                    symbolName: entry.symbol,
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    distanceMeters: dist,
                    prompt: prompt,
                    isVisited: false,
                    proximityState: .far   // updated by caller
                )
                results.append(spot)
                usedLocations.append(loc)
            }
        }

        return results
    }
}

// MARK: - CLLocationManagerDelegate

extension ExploreManager: CLLocationManagerDelegate {
    // Called when the user grants or denies location permission.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    // Fired when a location fix arrives.  We stop updating immediately so the
    // manager doesn't burn battery on continuous tracking.
    func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        manager.stopUpdatingLocation()
        Task { @MainActor in
            await self.refresh(around: loc)
        }
    }
}
