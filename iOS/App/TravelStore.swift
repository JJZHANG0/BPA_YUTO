import Foundation
import Observation

@MainActor
@Observable
final class TravelStore {
    let catalog: Catalog?
    private let preferences: TravelPreferences
    var profile: Profile {
        didSet { preferences.save(profile, for: .profile) }
    }
    private(set) var trips: [Trip] {
        didSet { preferences.save(trips, for: .trips) }
    }
    private(set) var reviews: [DestinationReview] {
        didSet { preferences.save(reviews, for: .reviews) }
    }
    private(set) var favorites: Set<String> {
        didSet { preferences.save(favorites, for: .favorites) }
    }

    init(catalog: Catalog?, preferences: TravelPreferences = TravelPreferences()) {
        self.catalog = catalog
        self.preferences = preferences
        let profile = preferences.load(.profile, default: Profile())
        self.profile = profile
        reviews = preferences.load(.reviews, default: [])
        favorites = preferences.load(.favorites, default: [])
        trips = preferences.load(.trips, default: [Trip]())
        if let catalog {
            let needsMigration = trips.contains { $0.itinerary == nil && catalog.destination($0.destination) != nil }
            if needsMigration {
                trips = trips.map { trip in
                    guard trip.itinerary == nil else { return trip }
                    var migrated = trip
                    let itinerary = TripPlanner.plan(trip, catalog: catalog, profile: profile)
                    if !itinerary.isEmpty { migrated.itinerary = itinerary }
                    return migrated
                }
                preferences.save(trips, for: .trips)
            }
        }
    }

    @discardableResult
    func addReview(destinationID: String, rating: Int, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard catalog?.destination(destinationID) != nil, (1...5).contains(rating),
              (1...500).contains(trimmed.count) else { return false }
        reviews.insert(DestinationReview(destinationID: destinationID, rating: rating, text: trimmed, date: .now), at: 0)
        return true
    }

    func deleteReview(_ id: UUID) {
        reviews.removeAll { $0.id == id }
    }

    func toggleFavorite(_ id: String) {
        if favorites.remove(id) == nil { favorites.insert(id) }
    }

    func saveTrip(_ trip: Trip) {
        guard let catalog else { return }
        let existing = trips.first { $0.id == trip.id }
        var updated = trip
        if let existing, existing.destination == trip.destination,
           existing.days == trip.days, existing.slow == trip.slow,
           let itinerary = existing.itinerary {
            updated.itinerary = itinerary
        } else {
            let itinerary = TripPlanner.plan(trip, catalog: catalog, profile: profile)
            guard !itinerary.isEmpty else { return }
            updated.itinerary = itinerary
        }
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = updated
        } else {
            trips.insert(updated, at: 0)
        }
    }

    func toggleCompletion(_ id: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[index].complete.toggle()
    }

    func deleteTrip(_ id: UUID) {
        trips.removeAll { $0.id == id }
    }
}
