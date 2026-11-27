import Foundation

struct Profile: Codable {
    var nickname = ""
    var age = "暂不填写"
    var wheelchair = false
    var shortWalk = false
    var restOften = false
    var slowPace = true
    var largerText = false
    var extraLargeText: Bool?
    var highContrast: Bool?
    var readAloud: Bool?
    var dietPreference: String?
    var mobilityNote: String?
    var helpContacts: [HelpContact]?
}

struct HelpContact: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var phone: String
    var role: String

    static func dialableNumber(_ input: String) -> String? {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace && !"-()（）".contains($0) }
        let digits = clean.hasPrefix("+") ? String(clean.dropFirst()) : clean
        guard (3...15).contains(digits.count), digits.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return clean
    }
}
