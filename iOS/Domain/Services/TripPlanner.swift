import Foundation

struct TripDay: Codable, Equatable {
    let destinationID: String?
    let title: String

    static let rest = TripDay(destinationID: nil, title: "自由活动与休息")
}

enum TripPlanner {
    static func suggestedTrip(in catalog: Catalog, profile: Profile, favorites: Set<String>) -> Trip? {
        let shortVisit = profile.shortWalk || profile.restOften || profile.wheelchair
        let slow = shortVisit || profile.slowPace
        let candidates = DestinationMatcher.search("", in: catalog, province: "", city: "", profile: profile)
        // Prefer a saved place; break ties using assessed facilities for the traveler's stated needs.
        let priorities = DestinationMatcher.neededDimensions(query: "", profile: profile)
        func rank(_ place: Destination) -> Int {
            let evidence = place.dimensions.filter { priorities.contains($0.name) }.compactMap(\.score)
            let suitability = evidence.isEmpty ? 0 : evidence.reduce(0, +) / evidence.count
            return (favorites.contains(place.id) ? 1000 : 0) + suitability * 2 + (place.score ?? place.previewScore ?? 0)
        }
        guard let first = candidates.max(by: { rank($0) < rank($1) }) else { return nil }
        let length = shortVisit || profile.age == "75岁及以上" ? 2 : 3
        var trip = Trip(destination: first.id, days: length, slow: slow)
        trip.itinerary = plan(trip, catalog: catalog, profile: profile)
        return trip
    }

    static func plan(_ trip: Trip, catalog: Catalog, profile: Profile) -> [TripDay] {
        guard let first = catalog.destination(trip.destination), (1...14).contains(trip.days) else {
            return []
        }
        let nearby = DestinationMatcher.search("", in: catalog, province: first.province, city: first.city, profile: profile)
            .filter { $0.id != first.id }
        return (0..<trip.days).map { index in
            if index == 0 { return TripDay(destinationID: first.id, title: first.name) }
            if trip.slow && !index.isMultiple(of: 2) { return .rest }
            let offset = (trip.slow ? index / 2 : index) - 1
            guard nearby.indices.contains(offset) else { return .rest }
            let destination = nearby[offset]
            return TripDay(destinationID: destination.id, title: destination.name)
        }
    }
}
