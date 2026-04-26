// ExploreManager.swift
// Signal
//
// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE NEARBY — SERVICE LAYER
// ─────────────────────────────────────────────────────────────────────────────
//
// ExploreManager does three things:
//   1. Asks CoreLocation for the user's current position.
//   2. Queries MapKit for nearby parks / green spaces / landmarks.
//   3. Tracks which spots the user has already visited (UserDefaults).
//
// It is a @MainActor class so its @Published properties and all mutations
// happen on the main thread — safe to subscribe from UIKit view controllers.
//
// PROXIMITY STATES
//   .far    — user is > 375 m away   → "Visit" button is disabled (greyed out)
//   .nearby — user is ≤ 375 m away   → "Visit" button active (partial XP)
//   .exact  — user is ≤  75 m away   → "Visit" button active (full XP)
//
// BADGE INTEGRATION
//   markVisited(_:) delegates to BadgeStore.recordParkVisit(), which returns
//   any newly unlocked BadgeDefinitions.  The caller (DashboardViewController)
//   is responsible for presenting the badge alert.
// ─────────────────────────────────────────────────────────────────────────────

import Combine
import CoreLocation
import Foundation
import MapKit

// MARK: - ExploreSpot

/// Lightweight, value-type representation of one nearby park / landmark.
/// Stored as plain Doubles so no CoreLocation import is needed in the UI layer.
struct ExploreSpot: Hashable, Sendable {

    enum ProximityState: Sendable {
        case far        // > 375 m — too far to check in
        case nearby     // ≤ 375 m — close enough for partial credit
        case exact      // ≤  75 m — right at the spot, full credit
    }

    /// Stable key derived from rounded coordinates so the same physical place
    /// always gets the same ID across refreshes.
    let id: String
    let name: String
    let categoryName: String
    let symbolName: String
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double
    let prompt: String          // Mindful nudge shown on the card
    var isVisited: Bool
    var proximityState: ProximityState

    // Hash keyed on `id` alone so the same physical place is stable across refreshes.
    // Equality also checks mutable state fields so DiffableDataSource detects when
    // isVisited or proximityState changes and reconfigures the cell automatically.
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

nonisolated final class ExploreManager: NSObject {

    // MARK: Published state

    /// The current list of nearby explore spots (up to 3).
    /// DashboardViewController subscribes to this with Combine.
    @Published private(set) var spots: [ExploreSpot] = []

    /// Mirrors CLLocationManager's authorization status so the UI can show
    /// a prompt or disable the section gracefully.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: Private

    private let locationManager = CLLocationManager()
    private let visitedKey = "signal.visitedExploreSpotIDs"

    // MARK: Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public API

    /// Call this in viewWillAppear. Requests authorization on first run;
    /// on subsequent calls with an authorized status it triggers a location fix
    /// which eventually fires `didUpdateLocations` → `refresh(around:)`.
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
    /// Call this directly in tests or when you already have a CLLocation.
    func refresh(around userLocation: CLLocation) async {
        var fetched = await fetchSpots(around: userLocation)
        let visited = visitedIDs()
        for i in fetched.indices {
            fetched[i].isVisited = visited.contains(fetched[i].id)
            fetched[i].proximityState = computeProximity(for: fetched[i], userLocation: userLocation)
        }
        // MapKit can return the same physical place from multiple category queries.
        // Deduplicate by id before publishing so DiffableDataSource never receives
        // two items with the same identifier.
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
    // `nonisolated` because CLLocationManagerDelegate doesn't run on MainActor.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        manager.stopUpdatingLocation()
        Task { @MainActor in
            await self.refresh(around: loc)
        }
    }
}
