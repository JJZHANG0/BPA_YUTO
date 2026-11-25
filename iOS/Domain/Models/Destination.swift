import Foundation

struct Destination: Codable, Identifiable, Hashable {
    struct Dimension: Codable, Hashable {
        struct Condition: Codable, Hashable {
            let name: String
            let confirmed: Bool
        }
        let name: String
        let score: Int?
        let conditions: [Condition]
    }

    let id: String
    let name: String
    let province: String
    let city: String
    let grade: String
    let score: Int?
    let rating: String?
    let dimensions: [Dimension]
    let notice: String
}

extension Destination {
    var featuredArtwork: String? {
        switch name {
        case "西湖风景名胜区": "WestLake"
        case "苏州园林（拙政园－留园－虎丘）": "SuzhouGarden"
        case "鼓浪屿旅游区": "Gulangyu"
        default: nil
        }
    }

    var shortName: String {
        switch featuredArtwork {
        case "WestLake": "杭州西湖"
        case "SuzhouGarden": "苏州园林"
        case "Gulangyu": "鼓浪屿"
        default: name.count > 8 ? String(name.prefix(7)) + "…" : name
        }
    }

    // Editorial estimates based on broad terrain and visit patterns. Never used in matching.
    var previewScore: Int? {
        switch featuredArtwork {
        case "WestLake": 86
        case "SuzhouGarden": 76
        case "Gulangyu": 68
        default: nil
        }
    }

    var scoreCaption: String? {
        if let score { return "银发友好度 \(score) 分" }
        if let previewScore { return "AI预估 \(previewScore) 分" }
        return nil
    }
}

struct DestinationReview: Codable, Identifiable {
    var id = UUID()
    let destinationID: String
    let rating: Int
    let text: String
    let date: Date
}
