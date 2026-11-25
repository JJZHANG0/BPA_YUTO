import Foundation

struct Trip: Codable, Identifiable {
    var id = UUID()
    var destination: String
    var origin = ""
    var date = Date()
    var days = 2
    var people = 2
    var slow = true
    var complete = false
    var itinerary: [TripDay]?
}
