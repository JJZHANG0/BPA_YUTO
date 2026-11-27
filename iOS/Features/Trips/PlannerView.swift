import SwiftUI

struct PlannerView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @FocusState private var composing: Bool
    @State private var text = ""
    @State private var replies: [PlannerExchange] = []
    @State private var conflict = false
    let catalog: Catalog
    var tripID: UUID?

    private var current: Trip? { store.trips.first { $0.id == tripID } }

    private var greeting: String {
        guard let trip = current else {
            return tripID == nil ? "您好！我是悠途的旅行助手。告诉我想去的地方、打算玩几天，我来帮您排一份适合慢慢走的行程。" : "原行程已删除，请返回行程列表。"
        }
        let name = catalog.destination(trip.destination)?.shortName ?? "这段旅程"
        return "我们来一起调整\(name)的\(trip.days)日行程。您想换个旅行节奏，还是调整天数？"
    }

    private var examples: [String] {
        if let trip = current {
            return ["调整为\(trip.days == 14 ? 13 : trip.days + 1)天", trip.slow ? "换成常规节奏" : "安排更多休息"]
        }
        return tripID == nil ? ["带父母去杭州，玩3天", "想去苏州园林，节奏轻松点", "一家人去云南旅行5天"] : []
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        YutoAssistantMark().frame(width: 72, height: 66).accessibilityHidden(true)
                        Text(greeting)
                            .font(.body).lineSpacing(4).travelPanel()
                    }
                    if replies.isEmpty && !examples.isEmpty {
                        if tripID == nil {
                            Button(action: suggestUsingProfile) {
                                Label("按我的偏好推荐路线", systemImage: "figure.walk")
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(YutoButtonStyle(primary: false))
                        }
                        Text("您可以这样告诉我").font(.headline)
                        ForEach(examples, id: \.self) { prompt in
                            Button { send(prompt) } label: {
                                HStack {
                                    Text(prompt)
                                    Spacer()
                                    Image(systemName: "arrow.up.left").font(.callout)
                                }.frame(minHeight: 44).padding(.horizontal, 13)
                                    .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                    ForEach(replies) { reply in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Spacer(minLength: 32)
                                Text(reply.request).padding(13)
                                    .background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 12))
                            }
                            Label("悠途规划师", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.sage)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(reply.message).lineSpacing(3)
                                if let trip = reply.draft {
                                    ForEach(Array((trip.itinerary ?? []).enumerated()), id: \.offset) { index, day in
                                        Text("第\(index + 1)天　\(day.title)").font(.subheadline)
                                    }
                                    Button {
                                        if let base = reply.base {
                                            if store.applyOptimization(trip, replacing: base) { dismiss() }
                                            else { conflict = true }
                                        } else {
                                            presentation.editing = store.trips.first { $0.id == trip.id } ?? trip
                                        }
                                    } label: {
                                        Label(reply.base == nil ? "查看并保存计划" : "保存到原行程", systemImage: "calendar.badge.checkmark")
                                            .frame(maxWidth: .infinity)
                                    }.buttonStyle(YutoButtonStyle())
                                }
                            }.travelPanel()
                        }.id(reply.id)
                    }
                }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: replies.count) { _, _ in
                if let last = replies.last { proxy.scrollTo(last.id, anchor: .top) }
            }
        }
        .background(YutoTheme.paper)
        .foregroundStyle(YutoTheme.ink)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("说说您的旅行想法…", text: $text, axis: .vertical)
                    .focused($composing).lineLimit(1...4).padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(minHeight: 46)
                    .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 18))
                Button { send(text) } label: {
                    Image(systemName: "arrow.up").font(.headline).frame(width: 46, height: 46)
                        .foregroundStyle(.white).background(YutoTheme.sage, in: Circle())
                }.accessibilityLabel("发送旅行想法").disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.horizontal, 16).padding(.vertical, 8).background(YutoTheme.paper)
        }
        .alert("请重新预览行程", isPresented: $conflict) {
            Button("好") { replies = [] }
        } message: { Text("原行程已更新或移除。请查看最新安排后再调整。") }
        .navigationTitle(tripID == nil ? "AI 旅行规划师" : "AI 优化行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Text("基于本机景区目录和行程规则规划")
                    Button("开始新规划", systemImage: "square.and.pencil") { replies = []; text = "" }
                } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("规划选项")
            }
        }
    }

    private func suggestUsingProfile() {
        guard let trip = TripPlanner.suggestedTrip(in: catalog, profile: store.profile, favorites: store.favorites),
              let destination = catalog.destination(trip.destination) else {
            replies.append(PlannerExchange(request: "按我的偏好推荐路线", message: "现有目录里还没有符合这些条件的路线。您可以换个城市试试。", draft: nil))
            return
        }
        let origin = store.favorites.contains(destination.id) ? "从您收藏的" : "从"
        var reason = origin + destination.shortName + "出发，建议先安排" + String(trip.days) + "天，每天最多一处景点。"
        if trip.slow { reason += "给休息和自由活动留出整天时间。" }
        if store.profile.wheelchair { reason += "出发前请向景区确认轮椅可走的入口和路线。" }
        replies.append(PlannerExchange(request: "按我的偏好推荐路线", message: reason, draft: trip))
    }

    private func send(_ input: String) {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        text = ""
        composing = false
        if let base = replies.compactMap(\.base).last, current?.hasSameSchedule(as: base) != true {
            conflict = true
            return
        }
        let previous = replies.compactMap(\.draft).last ?? current
        let candidates = DestinationMatcher.search(query, in: catalog, province: "", city: "", profile: store.profile)
        let nearby = candidates.filter { place in
            [place.name, place.shortName, place.province, place.city.replacingOccurrences(of: "市", with: "")]
                .contains { !$0.isEmpty && query.contains($0) }
        }
        let place = nearby.first { query.contains($0.shortName) || query.contains($0.name) }
            ?? nearby.first { $0.featuredArtwork != nil } ?? nearby.first
        let requestedDays = Self.days(in: query)
        let wantsRest = ["慢", "休息", "轻松", "少走"].contains(where: query.contains)
        let wantsCompact = ["紧凑", "充实", "常规"].contains(where: query.contains)
        let refining = requestedDays != nil || wantsRest || wantsCompact
        if tripID != nil && current == nil { conflict = true; return }
        if let current, !refining || (place != nil && place?.id != current.destination) {
            replies.append(PlannerExchange(request: query, message: "可以调整当前行程的天数或节奏。试试“改成4天”或“安排更多休息”。", draft: nil))
            return
        }
        let fallback = refining ? previous.flatMap { catalog.destination($0.destination) } : nil
        guard let destination = current.flatMap({ catalog.destination($0.destination) }) ?? place ?? fallback else {
            replies.append(PlannerExchange(request: query, message: "想从哪个城市或景区开始呢？试试“杭州西湖3天”或“苏州园林2天”。", draft: nil))
            return
        }
        if let requestedDays, !(1...14).contains(requestedDays) {
            replies.append(PlannerExchange(request: query, message: "每份计划可以安排 1 至 14 天。您希望这一段旅程玩几天？", draft: nil))
            return
        }
        var trip = current ?? Trip(destination: destination.id)
        trip.days = requestedDays ?? previous?.days ?? 3
        trip.slow = wantsCompact ? false : wantsRest || (previous?.slow ?? store.profile.slowPace)
        trip.itinerary = TripPlanner.plan(trip, catalog: catalog, profile: store.profile)
        let pace = trip.slow ? "留出休息时间" : "采用常规节奏"
        let message = "从\(destination.shortName)开始，安排\(trip.days)天，\(pace)。" +
            (current == nil ? "您可以继续调整，也可以打开计划选定出行日期。" : "确认下面的每日安排后，即可保存到原行程。")
        replies.append(PlannerExchange(request: query, message: message, draft: trip, base: current))
    }

    private static func days(in input: String) -> Int? {
        let normalized = input.replacingOccurrences(of: "两", with: "二")
        guard let range = normalized.range(of: "[0-9零一二三四五六七八九十百]+\\s*[天日]", options: .regularExpression) else { return nil }
        let number = String(normalized[range].dropLast()).trimmingCharacters(in: .whitespaces)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.numberStyle = .spellOut
        return Int(number) ?? formatter.number(from: number)?.intValue
    }
}

private struct PlannerExchange: Identifiable {
    let id = UUID()
    let request: String
    let message: String
    let draft: Trip?
    var base: Trip? = nil
}
