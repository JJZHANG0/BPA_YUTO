import Foundation

enum DestinationMatcher {
    static func search(_ input: String, in catalog: Catalog, province: String, city: String, profile: Profile) -> [Destination] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let local = catalog.attractions.filter { (province.isEmpty || province == $0.province) && (city.isEmpty || city == $0.city) }
        let named = local.filter {
            let cityName = $0.city.hasSuffix("市") ? String($0.city.dropLast()) : $0.city
            return [$0.name, $0.province, $0.city, cityName].contains { $0.contains(query) || query.contains($0) }
        }
        let general = ["旅行", "旅游", "出游", "轮椅", "台阶", "爬山", "老人", "出门"].contains { query.contains($0) }
        let candidates = query.isEmpty ? local : !named.isEmpty ? named : general ? local : []
        let dimensions = neededDimensions(query: query, profile: profile)
        return candidates.filter { place in
            !place.dimensions.contains { dimensions.contains($0.name) && ($0.score ?? 100) < 40 && $0.conditions.allSatisfy(\.confirmed) }
        }
    }

    static func neededDimensions(query: String, profile: Profile) -> Set<String> {
        var dimensions = Set<String>()
        if profile.wheelchair || query.contains("轮椅") { dimensions.insert("无障碍便利性") }
        if profile.shortWalk || ["爬山", "台阶", "少走", "爬坡"].contains(where: query.contains) {
            dimensions.insert("步行及体力负担")
        }
        if profile.restOften { dimensions.insert("休息设施") }
        return dimensions
    }
}
