import SwiftUI

struct ProvinceDirectoryRoute: Hashable {}

private enum DiscoveryTopic: String, CaseIterable, Identifiable {
    case featured = "热门推荐", ease = "适老参考", landscape = "山水自然", culture = "历史人文"
    var id: Self { self }

    func includes(_ place: Destination) -> Bool {
        switch self {
        case .featured: return true
        case .ease: return place.score != nil || place.previewScore != nil
        case .landscape:
            return ["山", "湖", "河", "谷", "岛", "海", "湿地", "草原", "瀑布", "梯田", "丹霞"].contains(where: place.name.contains)
        case .culture:
            return ["园林", "古镇", "古城", "文化", "纪念", "陵", "故里", "长城", "书院", "祠", "大院"].contains(where: place.name.contains)
        }
    }
}

struct DiscoverView: View {
    let catalog: Catalog
    let profile: Profile
    let visited: Set<String>
    @Binding var query: String
    @Environment(TravelStore.self) private var store
    @State private var topic = DiscoveryTopic.featured
    @State private var province = ""
    @State private var favoritesOnly = false
    @State private var showSearch = false
    @FocusState private var focused: Bool

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var places: [Destination] {
        let matches = DestinationMatcher.search(term, in: catalog, province: term.isEmpty ? province : "", city: "", profile: profile)
        // A query sent from Home searches the whole catalog, regardless of this tab's last filters.
        guard term.isEmpty else { return matches }
        return matches.filter { topic.includes($0) && (!favoritesOnly || store.favorites.contains($0.id)) }
            .sorted { lhs, rhs in
                if topic == .ease {
                    let left = lhs.score ?? lhs.previewScore ?? 0
                    let right = rhs.score ?? rhs.previewScore ?? 0
                    if left != right { return left > right }
                }
                let leftPriority = editorialOrder(lhs)
                let rightPriority = editorialOrder(rhs)
                return leftPriority == rightPriority ? lhs.id < rhs.id : leftPriority < rightPriority
            }
    }

    private func editorialOrder(_ place: Destination) -> Int {
        switch place.featuredArtwork {
        case "Gulangyu": 0
        case "WestLake": 1
        case "SuzhouGarden": 2
        default: 3
        }
    }

    var body: some View {
        let results = places
        YutoPage {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("发现")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("discover-title")
                    Spacer()
                    Button {
                        if showSearch || !term.isEmpty {
                            query = ""
                            showSearch = false
                        } else {
                            showSearch = true
                            focused = true
                        }
                    } label: {
                        Image(systemName: showSearch || !term.isEmpty ? "xmark" : "magnifyingglass")
                            .font(.headline).frame(width: 44, height: 44)
                            .background(YutoTheme.porcelain, in: Circle())
                            .overlay { Circle().strokeBorder(YutoTheme.divider) }
                    }
                    .accessibilityLabel(showSearch || !term.isEmpty ? "关闭搜索" : "搜索目的地")
                }
                if showSearch || !term.isEmpty {
                    YutoSearchField(query: $query, hint: "搜索城市、景区或旅行需求", onSubmit: { focused = false })
                        .focused($focused)
                }
                if term.isEmpty { topics }
            }

            if term.isEmpty {
                if let first = results.first, first.featuredArtwork != nil {
                    ScenicDestinationCard(place: first, caption: caption(for: first), wide: true)
                }
                filters
            }

            if results.isEmpty {
                ContentUnavailableView(favoritesOnly && term.isEmpty ? "还没有符合条件的收藏" : "没有找到景区",
                                       systemImage: favoritesOnly && term.isEmpty ? "heart" : "magnifyingglass",
                                       description: Text(term.isEmpty ? "试试其他主题或地区。" : "试试城市名或景区名。"))
            } else {
                let showHero = term.isEmpty && results.first?.featuredArtwork != nil
                DestinationResults(results: showHero ? Array(results.dropFirst()) : results, query: term)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ProvinceDirectoryRoute.self) { _ in
            ProvinceDirectory(catalog: catalog, profile: profile, visited: visited)
        }
    }

    private var topics: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(DiscoveryTopic.allCases) { item in
                    Button { topic = item } label: {
                        Text(item.rawValue).font(.subheadline.weight(.semibold))
                            .foregroundStyle(item == topic ? .white : YutoTheme.ink)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(item == topic ? YutoTheme.forest : YutoTheme.porcelain, in: Capsule())
                            .overlay { Capsule().strokeBorder(item == topic ? Color.clear : YutoTheme.divider) }
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == topic ? [.isSelected] : [])
                }
            }
        }.scrollIndicators(.hidden)
    }

    private var filters: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) { filterControls }
            VStack(alignment: .leading, spacing: 6) { filterControls }
        }
    }

    @ViewBuilder private var filterControls: some View {
        Menu {
            Picker("地区", selection: $province) {
                Text("全部地区").tag("")
                ForEach(catalog.provinces, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            filterLabel(province.isEmpty ? "全部地区" : province, icon: "chevron.down", active: !province.isEmpty)
        }
        Button { favoritesOnly.toggle() } label: {
            filterLabel("已收藏", icon: favoritesOnly ? "heart.fill" : "heart", active: favoritesOnly)
        }
        .accessibilityAddTraits(favoritesOnly ? [.isSelected] : [])
        NavigationLink(value: ProvinceDirectoryRoute()) {
            filterLabel("按省浏览", icon: "map", active: false)
        }.accessibilityIdentifier("discover-provinces")
    }

    private func filterLabel(_ title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Text(title)
            Image(systemName: icon).font(.caption)
        }
        .fixedSize(horizontal: true, vertical: false)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .foregroundStyle(active ? YutoTheme.sage : YutoTheme.ink)
        .background(active ? YutoTheme.mist : YutoTheme.porcelain, in: Capsule())
        .overlay { Capsule().strokeBorder(YutoTheme.divider) }
        .frame(minHeight: 44)
    }

    private func caption(for place: Destination) -> String {
        switch place.featuredArtwork {
        case "Gulangyu": "沿着海岸，去听小岛的琴声"
        case "WestLake": "绕湖漫步，看远山与亭影"
        case "SuzhouGarden": "穿过花窗，遇见一座江南庭院"
        default: place.city
        }
    }
}

private struct ProvinceDirectory: View {
    let catalog: Catalog
    let profile: Profile
    let visited: Set<String>
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        YutoPage {
            YutoScreenTitle(title: "按省探索")
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(catalog.provinces, id: \.self) { province in
                    let photo = ProvinceIllustration.photo(for: province)
                    NavigationLink {
                        ProvinceDestinations(catalog: catalog, profile: profile, province: province)
                    } label: {
                        YutoPhoto(name: photo.name, subdirectory: photo.folder)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.66)], startPoint: .center, endPoint: .bottom))
                            .overlay(alignment: .bottomLeading) {
                                HStack {
                                    Text(province).font(.system(.headline, design: .serif, weight: .bold))
                                    if visited.contains(province) { Image(systemName: "checkmark.seal.fill") }
                                }.padding(12).foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(visited.contains(province) ? "\(province)，已点亮" : province)
                    .accessibilityIdentifier("province-\(province)")
                }
            }
        }
        .navigationTitle("省份目录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct ProvinceDestinations: View {
    let catalog: Catalog
    let profile: Profile
    let province: String
    @State private var city = ""

    var body: some View {
        let cities = catalog.cities(in: province)
        let results = DestinationMatcher.search("", in: catalog, province: province, city: city, profile: profile)
        YutoPage {
            YutoScreenTitle(title: "\(province)景区")
            if cities.count > 1 {
                Picker("选择城市", selection: $city) {
                    Text("全部城市").tag("")
                    ForEach(cities, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            if results.isEmpty {
                ContentUnavailableView("这个地区暂无收录景区", systemImage: "map")
            } else {
                DestinationResults(results: results, query: "")
            }
        }
        .navigationTitle(province)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DestinationResults: View {
    let results: [Destination]
    let query: String

    var body: some View {
        LazyVStack(spacing: 9) {
            ForEach(results) { place in
                DiscoveryRow(place: place, query: query)
            }
        }
    }
}

private struct DiscoveryRow: View {
    let place: Destination
    let query: String
    @Environment(TravelStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let saved = store.favorites.contains(place.id)
        HStack(spacing: 4) {
            NavigationLink {
                DestinationDetailView(place: place, query: query)
            } label: {
                HStack(alignment: .center, spacing: 11) {
                    if !typeSize.isAccessibilitySize {
                        let regional = ProvinceIllustration.photo(for: place.province)
                        YutoPhoto(name: place.featuredArtwork ?? regional.name, subdirectory: place.featuredArtwork == nil ? regional.folder : nil)
                            .frame(width: 79, height: 66)
                            .overlay(alignment: .bottomTrailing) {
                                if place.featuredArtwork == nil {
                                    Text("地区图").font(.caption2).foregroundStyle(.white)
                                        .padding(.horizontal, 4).padding(.vertical, 2)
                                        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 3))
                                        .padding(3)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.shortName).font(.headline)
                            .accessibilityLabel(place.name)
                        Text("\(place.city) · \(place.grade) 景区").font(.subheadline).foregroundStyle(YutoTheme.muted)
                        if let caption = place.scoreCaption {
                            Text(caption).font(.footnote.weight(.medium)).foregroundStyle(YutoTheme.sage)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8)
                .foregroundStyle(YutoTheme.ink)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("discover-place-\(place.name)")
            Button { store.toggleFavorite(place.id) } label: {
                Image(systemName: saved ? "heart.fill" : "heart")
                    .font(.body).foregroundStyle(saved ? YutoTheme.sage : YutoTheme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(saved ? "取消收藏" : "收藏")\(place.shortName)")
        }
        .padding(.leading, 8).padding(.trailing, 3)
        .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: YutoTheme.round))
        .overlay { RoundedRectangle(cornerRadius: YutoTheme.round).strokeBorder(YutoTheme.divider).allowsHitTesting(false) }
    }
}
