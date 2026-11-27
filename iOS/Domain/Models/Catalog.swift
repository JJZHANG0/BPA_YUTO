import Foundation

struct Catalog: Decodable {
    let provinces: [String]
    let attractions: [Destination]

    func destination(_ id: String) -> Destination? {
        attractions.first { $0.id == id }
    }

    func provinces(in trip: Trip) -> Set<String> {
        let stops = trip.itinerary?.compactMap(\.destinationID) ?? []
        return Set(([trip.destination] + stops).compactMap { destination($0)?.province })
    }

    func visitedProvinces(in trips: [Trip]) -> Set<String> {
        Set(trips.filter(\.complete).flatMap { provinces(in: $0) })
    }

    func cities(in province: String) -> [String] {
        Array(Set(attractions.filter { $0.province == province }.map(\.city))).sorted()
    }
}
