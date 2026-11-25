import Foundation

@main
struct TravelCoreChecks {
    @MainActor
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        precondition(catalog.provinces.count == 31)
        precondition(catalog.attractions.count == 103)
        precondition(Set(catalog.attractions.map(\.id)).count == 103)
        precondition(catalog.attractions.allSatisfy { $0.dimensions.count == 6 })

        let suite = "yuto.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = TravelPreferences(defaults: defaults)
        let store = TravelStore(catalog: catalog, preferences: preferences)

        let results = DestinationMatcher.search("想去浙江旅游，不爬山", in: catalog, province: "", city: "", profile: store.profile)
        precondition(!results.isEmpty && results.allSatisfy { $0.province == "浙江" })
        let first = catalog.attractions.first { $0.name == "西湖风景名胜区" }!
        let trip = Trip(destination: first.id, days: 4, slow: true)
        store.saveTrip(trip)
        let saved = store.trips[0].itinerary!
        precondition(saved.count == 4 && saved[0].destinationID == first.id && saved[1] == .rest)
        let scheduled = saved.compactMap { $0.destinationID }.compactMap(catalog.destination)
        precondition(scheduled.allSatisfy { $0.city == first.city && $0.province == first.province })

        store.profile.nickname = "悠途测试"
        store.profile.wheelchair = true
        store.toggleFavorite(first.id)
        precondition(catalog.visitedProvinces(in: store.trips).isEmpty)
        store.toggleCompletion(trip.id)
        precondition(catalog.visitedProvinces(in: store.trips) == ["浙江"])
        precondition(first.shortName == "杭州西湖" && first.scoreCaption == "AI预估 86 分")
        var edited = store.trips[0]
        edited.origin = "北京"
        store.saveTrip(edited)

        precondition(!store.addReview(destinationID: first.id, rating: 7, text: "无效"))
        precondition(!store.addReview(destinationID: first.id, rating: 5, text: "  "))
        precondition(store.addReview(destinationID: first.id, rating: 4, text: " 湖边慢走 "))
        let reopened = TravelStore(catalog: catalog, preferences: preferences)
        precondition(reopened.reviews.first?.text == "湖边慢走")
        if let review = reopened.reviews.first { reopened.deleteReview(review.id) }
        precondition(TravelStore(catalog: catalog, preferences: preferences).reviews.isEmpty)
        precondition(reopened.profile.nickname == "悠途测试")
        precondition(reopened.favorites == [first.id])
        precondition(reopened.trips[0].complete && reopened.trips[0].itinerary == saved)
        reopened.deleteTrip(trip.id)
        precondition(TravelStore(catalog: catalog, preferences: preferences).trips.isEmpty)

        preferences.save([trip], for: .trips)
        let migrated = TravelStore(catalog: catalog, preferences: preferences)
        precondition(migrated.trips[0].itinerary?.count == 4)
        let persisted = preferences.load(.trips, default: [Trip]())
        precondition(persisted.first?.itinerary == migrated.trips[0].itinerary)
        print("通过：离线目录、目的地匹配、行程规则、数据持久化和旧版行程迁移")
    }
}
