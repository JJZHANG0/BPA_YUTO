import Foundation

struct Catalog: Decodable {
    let provinces: [String]
    let attractions: [Destination]

    func destination(_ id: String) -> Destination? {
        attractions.first { $0.id == id }
    }

    func visitedProvinces(in trips: [Trip]) -> Set<String> {
        Set(trips.filter(\.complete).flatMap { trip in
            let ids = trip.itinerary?.compactMap(\.destinationID) ?? [trip.destination]
            return ids.compactMap { destination($0)?.province }
        })
    }

    func cities(in province: String) -> [String] {
        Array(Set(attractions.filter { $0.province == province }.map(\.city))).sorted()
    }
}
