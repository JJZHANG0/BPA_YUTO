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

        let oldProfile = try JSONDecoder().decode(Profile.self, from: Data(#"{"nickname":"老赵","age":"65–74岁","wheelchair":false,"shortWalk":true,"restOften":false,"slowPace":true,"largerText":true}"#.utf8))
        precondition(oldProfile.nickname == "老赵" && oldProfile.largerText && oldProfile.helpContacts == nil)
        precondition(HelpContact.dialableNumber("+86 (139) 0000-0000") == "+8613900000000")
        precondition(HelpContact.dialableNumber("12#3") == nil)
        let results = DestinationMatcher.search("想去浙江旅游，不爬山", in: catalog, province: "", city: "", profile: store.profile)
        precondition(!results.isEmpty && results.allSatisfy { $0.province == "浙江" })
        let first = catalog.attractions.first { $0.name == "西湖风景名胜区" }!
        let recommended = TripPlanner.suggestedTrip(in: catalog, profile: oldProfile, favorites: [first.id])
        precondition(recommended?.destination == first.id && recommended?.days == 2 && recommended?.itinerary?.last == .rest)
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
        store.markProvince("四川")
        store.markProvince("浙江")
        store.markProvince("非省份")
        let footprints = TravelStore(catalog: catalog, preferences: preferences)
        precondition(footprints.visitedProvinces(in: catalog) == ["四川", "浙江"])
        footprints.removeManualFootprint("浙江")
        precondition(footprints.manualFootprints["浙江"] != nil)
        footprints.removeManualFootprint("四川")
        let afterUndo = TravelStore(catalog: catalog, preferences: preferences)
        precondition(afterUndo.visitedProvinces(in: catalog) == ["浙江"])
        afterUndo.toggleCompletion(trip.id)
        afterUndo.removeManualFootprint("浙江")
        precondition(afterUndo.visitedProvinces(in: catalog).isEmpty)
        afterUndo.toggleCompletion(trip.id)
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
        var futureTrip = Trip(destination: first.id)
        futureTrip.date = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        futureTrip.lodgingPlan = "住在湖边"
        futureTrip.mealPlan = "和家人一起午餐"
        migrated.saveTrip(futureTrip)
        let reminder = TripReminder(kind: .meet, day: 2, hour: 10, minute: 15, voice: false)
        precondition(migrated.saveReminder(reminder, for: futureTrip.id))
        migrated.toggleSavedRoute(futureTrip.id)
        let initialTime = reminder.date(for: futureTrip)!
        futureTrip.date = Calendar.current.date(byAdding: .day, value: 1, to: futureTrip.date)!
        migrated.saveTrip(futureTrip)
        let recovered = TravelStore(catalog: catalog, preferences: preferences).trips.first { $0.id == futureTrip.id }!
        precondition(recovered.reminders == [reminder] && recovered.savedRoute == true)
        precondition(recovered.mealPlan == futureTrip.mealPlan && recovered.lodgingPlan == futureTrip.lodgingPlan)
        precondition(Calendar.current.dateComponents([.day], from: initialTime, to: reminder.date(for: recovered)!).day == 1)
        futureTrip.days = 1
        precondition(reminder.date(for: futureTrip) == nil)
        migrated.removeReminder(reminder.id, from: futureTrip.id)
        precondition(migrated.trips.first { $0.id == futureTrip.id }?.reminders?.isEmpty == true)
        print("通过：离线目录、目的地匹配、行程规则、数据持久化和旧版行程迁移")
    }
}
