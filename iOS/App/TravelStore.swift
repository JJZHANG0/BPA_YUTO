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
    private(set) var companions: [TravelCompanion] {
        didSet { preferences.save(companions, for: .companions) }
    }

    init(catalog: Catalog?, preferences: TravelPreferences = TravelPreferences()) {
        self.catalog = catalog
        self.preferences = preferences
        let profile = preferences.load(.profile, default: Profile())
        self.profile = profile
        reviews = preferences.load(.reviews, default: [])
        favorites = preferences.load(.favorites, default: [])
        companions = preferences.load(.companions, default: [])
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
        if let existing {
            updated.familyNotes = existing.familyNotes
            updated.expenses = existing.expenses
        }
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

    func applyOptimization(_ draft: Trip, replacing base: Trip) -> Bool {
        guard draft.id == base.id, draft.destination == base.destination,
              (1...14).contains(draft.days), let itinerary = draft.itinerary, itinerary.count == draft.days,
              let index = trips.firstIndex(where: { $0.id == base.id }) else { return false }
        let current = trips[index]
        guard current.hasSameSchedule(as: base) else { return false }
        var changed = current
        changed.days = draft.days
        changed.slow = draft.slow
        changed.itinerary = itinerary
        trips[index] = changed
        return true
    }

    func addExpense(label: String, amount: String, to tripID: UUID) {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= 30, let cents = TripExpense.cents(from: amount),
              let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var expenses = trips[index].expenses ?? []
        expenses.append(TripExpense(label: label, cents: cents))
        trips[index].expenses = expenses
    }

    func removeExpense(_ expenseID: UUID, from tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].expenses?.removeAll { $0.id == expenseID }
    }

    func deleteTrip(_ id: UUID) {
        trips.removeAll { $0.id == id }
    }

    func addCompanion(name: String, role: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24 else { return }
        companions.append(TravelCompanion(name: name, role: role))
    }

    func removeCompanion(_ id: UUID) {
        companions.removeAll { $0.id == id }
    }

    func addFamilyNote(_ text: String, to tripID: UUID) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500,
              let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        var notes = trips[index].familyNotes ?? []
        notes.insert(FamilyNote(text: text, date: .now), at: 0)
        trips[index].familyNotes = notes
    }

    func removeFamilyNote(_ noteID: UUID, from tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[index].familyNotes?.removeAll { $0.id == noteID }
    }
}
