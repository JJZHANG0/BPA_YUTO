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
    var familyNotes: [FamilyNote]?
    var expenses: [TripExpense]?

    func hasSameSchedule(as other: Trip) -> Bool {
        destination == other.destination && days == other.days && slow == other.slow && itinerary == other.itinerary
    }
}

struct TripExpense: Codable, Identifiable {
    var id = UUID()
    let label: String
    let cents: Int

    static func cents(from input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[0-9]{1,8}(?:[.][0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else { return nil }
        return NSDecimalNumber(decimal: amount * 100).intValue
    }

    static func yuan(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: "CNY").locale(Locale(identifier: "zh_CN")))
    }
}

struct FamilyNote: Codable, Identifiable {
    var id = UUID()
    let text: String
    let date: Date
}

struct TravelCompanion: Codable, Identifiable {
    var id = UUID()
    let name: String
    let role: String
}
