import SwiftUI

struct HomeView: View {
    let catalog: Catalog
    let visitedCount: Int
    @Binding var query: String
    let search: () -> Void
    let plan: () -> Void
    let trips: () -> Void
    let family: () -> Void
    let footprints: () -> Void
    let assistance: () -> Void

    @Environment(TravelStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var searching: Bool

    private var greeting: String {
        let welcome: String
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: welcome = "早上好"
        case 11..<14: welcome = "中午好"
        case 14..<18: welcome = "下午好"
        default: welcome = "晚上好"
        }
        let name = store.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? welcome : "\(welcome)，\(name)"
    }

    var body: some View {
        YutoPage {
            VStack(alignment: .leading, spacing: 11) {
                let header = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                header {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(greeting)
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("今天想去哪里旅行？")
                            .font(.body).foregroundStyle(YutoTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HomeWeatherBar()
                }
                HStack(spacing: 8) {
                    YutoSearchField(query: $query, hint: "搜索目的地、景点或玩法", onSubmit: submit)
                        .focused($searching)
                    if searching || !query.isEmpty {
                        Button("搜索", action: submit)
                            .font(.headline).fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }

            Button(action: plan) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.subheadline).foregroundStyle(YutoTheme.amberSurface)
                            Text("AI 智能规划旅行")
                                .font(.system(.title3, design: .serif, weight: .bold))
                        }
                        Text("说说您的想法，一起安排行程")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize {
                        YutoAssistantMark().frame(width: 70, height: 70).accessibilityHidden(true)
                    }
                }
                .padding(.leading, 18).padding(.trailing, 12).padding(.vertical, 10)
                .frame(minHeight: 94)
                .foregroundStyle(.white)
                .background {
                    YutoPhoto(name: "WelcomeLake")
                        .overlay(LinearGradient(colors: [YutoTheme.forest, YutoTheme.forest.opacity(0.95),
                                                         YutoTheme.forest.opacity(0.60)],
                                                startPoint: .leading, endPoint: .trailing))
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-planner")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    YutoSection(title: "为您推荐")
                    Spacer()
                    Button {
                        query = ""
                        submit()
                    } label: {
                        HStack(spacing: 4) {
                            Text("查看更多")
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }
                }
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12),
                                    count: typeSize.isAccessibilitySize ? 1 : 2)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(["WestLake", "SuzhouGarden"], id: \.self) { image in
                        if let place = catalog.attractions.first(where: { $0.featuredArtwork == image }) {
                            ScenicDestinationCard(place: place, caption: image == "WestLake" ? "烟波湖光 · 湖畔漫步" : "亭台水榭 · 江南园林")
                        }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                     count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 12) {
                shortcut("AI 规划", symbol: "sparkles", action: plan)
                shortcut("行程管理", symbol: "calendar", action: trips)
                shortcut("家人协作", symbol: "person.2", action: family)
                shortcut("出行求助", symbol: "phone.bubble", action: assistance)
            }
            Button(action: footprints) {
                HStack(spacing: 12) {
                    if !typeSize.isAccessibilitySize {
                        YutoArtwork(name: "ExplorationMap").frame(width: 88, height: 68)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("点亮中国").font(.system(.title3, design: .serif, weight: .bold))
                        Text("已走过 \(visitedCount) / \(catalog.provinces.count) 个省级地区")
                            .font(.subheadline).foregroundStyle(YutoTheme.muted)
                        ProgressView(value: Double(visitedCount), total: Double(max(1, catalog.provinces.count)))
                            .tint(YutoTheme.forest).frame(maxWidth: 140)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.forest)
                        .frame(width: 30, height: 30)
                        .background(YutoTheme.porcelain, in: Circle())
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(YutoTheme.ink)
                .background(LinearGradient(colors: [YutoTheme.mist, YutoTheme.porcelain], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: YutoTheme.round))
                .overlay { RoundedRectangle(cornerRadius: YutoTheme.round).strokeBorder(YutoTheme.greyGreen).allowsHitTesting(false) }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开可缩放的三维省份足迹地图")
            .accessibilityIdentifier("home-footprints")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit() {
        searching = false
        search()
    }

    private func shortcut(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3.weight(.medium)).foregroundStyle(YutoTheme.sage)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(YutoTheme.divider) }
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(YutoTheme.ink)
            }
        }.buttonStyle(.plain)
    }
}
