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
        store.addCompanion(name: " 妈妈 ", role: "家人")
        store.addFamilyNote(" 午后休息 ", to: edited.id)
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
        precondition(reopened.companions.map(\.name) == ["妈妈"])
        precondition(reopened.trips[0].familyNotes?.map(\.text) == ["午后休息"])
        if let note = reopened.trips[0].familyNotes?.first, let person = reopened.companions.first {
            reopened.removeFamilyNote(note.id, from: reopened.trips[0].id)
            reopened.removeCompanion(person.id)
        }
        let afterRemoval = TravelStore(catalog: catalog, preferences: preferences)
        precondition(afterRemoval.trips[0].familyNotes?.isEmpty == true && afterRemoval.companions.isEmpty)
        precondition(reopened.favorites == [first.id])
        precondition(reopened.trips[0].complete && reopened.trips[0].itinerary == saved)
        let base = reopened.trips[0]
        var preview = base
        preview.days = 3
        preview.slow = false
        preview.itinerary = TripPlanner.plan(preview, catalog: catalog, profile: reopened.profile)
        reopened.addExpense(label: "车票", amount: "0", to: base.id)
        reopened.addExpense(label: "车票", amount: "25.001", to: base.id)
        reopened.addExpense(label: "车票", amount: "25.40", to: base.id)
        reopened.addFamilyNote("午饭在湖边", to: base.id)
        var changed = base
        changed.people = 3
        reopened.saveTrip(changed)
        precondition(reopened.applyOptimization(preview, replacing: base))
        precondition(!reopened.applyOptimization(preview, replacing: base))
        let optimized = TravelStore(catalog: catalog, preferences: preferences).trips[0]
        precondition(optimized.id == base.id && optimized.days == 3 && !optimized.slow)
        precondition(optimized.origin == base.origin && optimized.date == base.date && optimized.people == 3)
        precondition(optimized.expenses?.map(\.cents) == [2540] && optimized.familyNotes?.first?.text == "午饭在湖边")
        reopened.removeExpense(optimized.expenses![0].id, from: base.id)
        precondition(TravelStore(catalog: catalog, preferences: preferences).trips[0].expenses?.isEmpty == true)
        reopened.deleteTrip(trip.id)
        precondition(!reopened.applyOptimization(preview, replacing: base))
        precondition(TravelStore(catalog: catalog, preferences: preferences).trips.isEmpty)

        preferences.save([trip], for: .trips)
        let migrated = TravelStore(catalog: catalog, preferences: preferences)
        precondition(migrated.trips[0].itinerary?.count == 4)
        let persisted = preferences.load(.trips, default: [Trip]())
        precondition(persisted.first?.itinerary == migrated.trips[0].itinerary)
        print("通过：离线目录、目的地匹配、行程规则、数据持久化和旧版行程迁移")
    }
}
