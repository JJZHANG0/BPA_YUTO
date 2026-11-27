import SwiftUI

struct TripEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var trip: Trip
    let catalog: Catalog
    let save: (Trip) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    let place = catalog.destination(trip.destination)
                    TravelCover(place: place, title: place?.shortName ?? "旅行计划",
                                subtitle: trip.displayDates + "  ·  \(trip.people)人同行")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent("出发城市") {
                        TextField("出发城市", text: $trip.origin, prompt: Text("选填").foregroundStyle(YutoTheme.muted))
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("第一站", selection: $trip.destination) {
                        ForEach(catalog.attractions) { place in
                            Text("\(place.city) · \(place.name)").tag(place.id)
                        }
                    }
                } header: { Text("目的地").foregroundStyle(YutoTheme.muted) }
                    .listRowBackground(YutoTheme.porcelain)
                Section {
                    DatePicker("出行日期", selection: $trip.date, displayedComponents: .date)
                    Stepper("旅行天数 · \(trip.days) 天", value: $trip.days, in: 1...14)
                    Stepper("同行人数 · \(trip.people) 人", value: $trip.people, in: 1...30)
                    Toggle("安排更多休息日", isOn: $trip.slow)
                } header: { Text("日期与节奏").foregroundStyle(YutoTheme.muted) }
                    .listRowBackground(YutoTheme.porcelain)
                Section("食宿计划") {
                    TextField("住宿名称或要求", text: Binding(
                        get: { trip.lodgingPlan ?? "" }, set: { trip.lodgingPlan = String($0.prefix(160)) }
                    ), axis: .vertical)
                    TextField("餐厅或用餐安排", text: Binding(
                        get: { trip.mealPlan ?? "" }, set: { trip.mealPlan = String($0.prefix(160)) }
                    ), axis: .vertical)
                }.listRowBackground(YutoTheme.porcelain)
            }
            .scrollContentBackground(.hidden)
            .background(YutoTheme.paper)
            .navigationTitle("旅行计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存计划") { save(trip) }.bold() }
            }
        }
    }
}
