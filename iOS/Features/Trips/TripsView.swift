import SwiftUI

struct TripsView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    @State private var selectedID: UUID?
    @State private var deleting: Trip?
    @State private var section = 0
    let catalog: Catalog

    private var selected: Trip? {
        store.trips.first { $0.id == selectedID } ?? store.trips.first
    }

    var body: some View {
        YutoPage {
            HStack {
                YutoScreenTitle(title: "我的行程")
                if !store.trips.isEmpty {
                    Button(action: start) {
                        Image(systemName: "plus").frame(width: 44, height: 44)
                            .background(YutoTheme.porcelain, in: Circle())
                    }.accessibilityLabel("创建旅行计划")
                }
            }
            if let trip = selected {
                let place = catalog.destination(trip.destination)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("已保存的行程").font(.headline)
                        Spacer()
                        if store.trips.count > 1 {
                            Menu {
                                ForEach(store.trips) { item in
                                    Button { selectedID = item.id } label: {
                                        Text("\(catalog.destination(item.destination)?.shortName ?? "行程") · \(item.date.formatted(.dateTime.month().day()))")
                                    }
                                }
                            } label: { Label("切换行程", systemImage: "arrow.left.arrow.right").font(.subheadline) }
                            .frame(minHeight: 44)
                        }
                    }
                    TravelCover(place: place, title: "\(place?.city ?? "旅行") · \(trip.days)日游",
                                subtitle: trip.displayDates + "  ·  \(trip.people)人同行")
                }
                Picker("行程视图", selection: $section) {
                    Text("行程安排").tag(0)
                    Text("行程总览").tag(1)
                    Text("费用清单").tag(2)
                }.pickerStyle(.segmented)
                if section == 0 {
                    itinerary(trip)
                } else if section == 1 {
                    overview(trip, place: place)
                } else {
                    TripExpensesView(trip: trip).id(trip.id)
                }
                HStack {
                    if section == 0 {
                        NavigationLink { PlannerView(catalog: catalog, tripID: trip.id) } label: {
                            Label("AI 优化行程", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }.buttonStyle(YutoButtonStyle())
                        Button { presentation.editing = trip } label: {
                            Image(systemName: "pencil").frame(width: 46, height: 46)
                                .background(YutoTheme.mist, in: Circle())
                        }.accessibilityLabel("修改行程")
                    } else {
                        Button { presentation.editing = trip } label: {
                            Label("修改行程", systemImage: "pencil.line").frame(maxWidth: .infinity)
                        }.buttonStyle(YutoButtonStyle(primary: false))
                    }
                    Menu {
                        Button(trip.complete ? "设为待出发" : "标记完成") { store.toggleCompletion(trip.id) }
                        ShareLink(item: trip.shareSummary(catalog: catalog))
                        Button("删除行程", role: .destructive) { deleting = trip }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 48, height: 48)
                            .background(YutoTheme.mist, in: Circle())
                    }.accessibilityLabel("更多行程操作")
                }
            } else {
                TravelCover(place: nil, title: "下一程，慢慢走", subtitle: "从一个想去的地方开始。")
                VStack(alignment: .leading, spacing: 14) {
                    Label("规划第一段旅程", systemImage: "calendar.badge.plus")
                        .font(.title3.bold())
                    Text("选好第一站、天数和同行人数，悠途会为您排好每天的游览和休息。")
                        .foregroundStyle(YutoTheme.muted)
                    Button(action: start) {
                        Label("创建旅行计划", systemImage: "plus").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle())
                    NavigationLink { PlannerView(catalog: catalog) } label: {
                        Label("和规划师聊聊", systemImage: "sparkles").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle(primary: false))
                }.travelPanel()
            }
        }
        .navigationTitle("我的行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("删除这份旅行计划？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible, presenting: deleting) { trip in
            Button("删除", role: .destructive) { store.deleteTrip(trip.id) }
            Button("取消", role: .cancel) {}
        }
    }

    private func start() {
        if let first = catalog.attractions.first(where: { $0.featuredArtwork == "WestLake" }) ?? catalog.attractions.first {
            presentation.editing = Trip(destination: first.id, slow: store.profile.slowPace)
        }
    }

    private func itinerary(_ trip: Trip) -> some View {
        let days = trip.itinerary ?? TripPlanner.plan(trip, catalog: catalog, profile: store.profile)
        return VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(YutoTheme.sage).frame(width: 10, height: 10)
                        if index + 1 < days.count { Rectangle().fill(YutoTheme.divider).frame(width: 2) }
                    }.padding(.top, 5).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        let date = Calendar.current.date(byAdding: .day, value: index, to: trip.date) ?? trip.date
                        Text("第\(index + 1)天 · \(date.formatted(.dateTime.month().day().weekday().locale(Locale(identifier: "zh_CN"))))")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.sage)
                        if let id = day.destinationID, let place = catalog.destination(id) {
                            NavigationLink { DestinationDetailView(place: place, query: "") } label: {
                                HStack {
                                    PlaceImage(place: place).frame(width: 58, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                    Text(day.title).font(.body.weight(.medium))
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(YutoTheme.muted)
                                }.travelPanel(10)
                            }.buttonStyle(.plain)
                        } else {
                            Label(day.title, systemImage: "cup.and.saucer")
                                .frame(maxWidth: .infinity, alignment: .leading).travelPanel()
                        }
                    }.padding(.bottom, index + 1 < days.count ? 16 : 0)
                }
            }
        }
    }

    private func overview(_ trip: Trip, place: Destination?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(trip.complete ? "已完成" : "待出发", systemImage: trip.complete ? "checkmark.seal" : "calendar")
                .font(.headline).foregroundStyle(YutoTheme.sage)
            if !trip.origin.isEmpty { LabeledContent("出发地", value: trip.origin) }
            LabeledContent("第一站", value: place?.name ?? "已保存的目的地")
            LabeledContent("出游节奏", value: trip.slow ? "多安排休息" : "常规节奏")
            LabeledContent("同行人数", value: "\(trip.people)人")
        }.travelPanel()
    }
}

extension Trip {
    var displayDates: String {
        let end = Calendar.current.date(byAdding: .day, value: max(0, days - 1), to: date) ?? date
        let format = Date.FormatStyle().month().day().locale(Locale(identifier: "zh_CN"))
        return days == 1 ? date.formatted(format) : date.formatted(format) + " – " + end.formatted(format)
    }

    func shareSummary(catalog: Catalog) -> String {
        let name = catalog.destination(destination)?.name ?? "我的旅行"
        let days = (itinerary ?? []).enumerated().map { "第\($0.offset + 1)天　\($0.element.title)" }
        return (["悠途 · " + name, displayDates + " · \(people)人同行"] + days).joined(separator: "\n")
    }
}
