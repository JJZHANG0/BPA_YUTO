import Foundation

struct TripDay: Codable, Equatable {
    let destinationID: String?
    let title: String

    static let rest = TripDay(destinationID: nil, title: "自由活动与休息")
}

enum TripPlanner {
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
