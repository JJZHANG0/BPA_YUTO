import SwiftUI

struct TripsView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    @State private var showDelete = false
    @State private var deleting: Trip?
    let catalog: Catalog

    var body: some View {
        YutoPage {
            YutoScreenTitle(title: "我的行程")
            Button {
                if let first = catalog.attractions.first {
                    presentation.editing = Trip(destination: first.id, slow: store.profile.slowPace)
                }
            } label: {
                Label("创建旅行计划", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(YutoButtonStyle())
            .disabled(catalog.attractions.isEmpty)
            YutoSection(title: "已保存的行程")
            if store.trips.isEmpty {
                Text("还没有行程。选择第一站和出行日期，就能生成每日安排。")
                    .foregroundStyle(YutoTheme.muted)
            }
            ForEach(store.trips) { trip in
                tripCard(trip)
            }
        }
        .navigationTitle("行程")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除这份旅行计划？", isPresented: $showDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let deleting { store.deleteTrip(deleting.id) }
                deleting = nil
            }
        }
    }

    private func tripCard(_ trip: Trip) -> some View {
        let itinerary = trip.itinerary ?? TripPlanner.plan(trip, catalog: catalog, profile: store.profile)
        let destination = catalog.destination(trip.destination)?.name ?? itinerary.first?.title ?? "已保存行程"
        return VStack(alignment: .leading, spacing: 14) {
            YutoSection(title: destination, detail: trip.date.formatted(date: .abbreviated, time: .omitted) + " · \(trip.people) 人")
            Label(trip.complete ? "已完成" : "待出发", systemImage: trip.complete ? "checkmark.circle" : "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.sage)
            if !trip.origin.isEmpty { Text("从\(trip.origin)出发").font(.subheadline) }
            Divider()
            ForEach(Array(itinerary.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: 12) {
                    Text("第 \(index + 1) 天").font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(YutoTheme.sage)
                    Text(day.title).font(.body)
                }
            }
            Text("出发前请确认开放时间、交通耗时与步行条件。")
                .font(.subheadline).foregroundStyle(YutoTheme.muted)
            Button("修改行程") { presentation.editing = trip }
                .buttonStyle(YutoButtonStyle(primary: false))
            Menu {
                Button(trip.complete ? "设为待出发" : "标记完成") { store.toggleCompletion(trip.id) }
                Button("删除行程", role: .destructive) { deleting = trip; showDelete = true }
            } label: {
                Label("更多行程操作", systemImage: "ellipsis.circle")
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider() }
    }
}
