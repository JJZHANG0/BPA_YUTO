import SwiftUI

enum ProvinceIllustration {
    static func photo(for province: String) -> (name: String, folder: String?) {
        switch province {
        case "浙江": ("WestLake", nil)
        case "江苏": ("SuzhouGarden", nil)
        case "福建": ("Gulangyu", nil)
        default: (province, "ProvinceCovers")
        }
    }
}

struct DiscoverView: View {
    let catalog: Catalog
    let profile: Profile
    let visited: Set<String>
    @Binding var query: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        YutoPage {
            YutoScreenTitle(title: "发现目的地")
            YutoSearchField(query: $query, hint: "城市、景区或旅行需求")
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2)
                LazyVGrid(columns: columns, spacing: 19) {
                    ForEach(catalog.provinces, id: \.self) { province in
                        NavigationLink(value: province) {
                            provinceTile(province)
                        }.buttonStyle(.plain).accessibilityIdentifier("province-\(province)")
                    }
                }
                Text("部分省份封面为景观示意。")
                    .font(.subheadline).foregroundStyle(YutoTheme.muted)
            } else {
                let results = DestinationMatcher.search(query, in: catalog, province: "", city: "", profile: profile)
                DestinationResults(results: results, query: query, emptyTitle: "没有找到景区")
            }
        }
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { province in
            ProvinceDestinations(catalog: catalog, profile: profile, province: province)
        }
    }

    private func provinceTile(_ province: String) -> some View {
        let isVisited = visited.contains(province)
        let photo = ProvinceIllustration.photo(for: province)
        return VStack(alignment: .leading, spacing: 8) {
            YutoPhoto(name: photo.name, subdirectory: photo.folder)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
            HStack(spacing: 6) {
                Text(province).font(.headline)
                if isVisited {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(YutoTheme.sage)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 3)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(YutoTheme.muted).accessibilityHidden(true)
            }
            .padding(.horizontal, 1)
        }
        .contentShape(.rect)
        .accessibilityLabel(isVisited ? "\(province)，已点亮" : province)
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
                HStack {
                    Text("城市").accessibilityHidden(true)
                    Spacer()
                    Picker("城市", selection: $city) {
                        Text("全部城市").tag("")
                        ForEach(cities, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 16))
            }
            DestinationResults(results: results, query: "", emptyTitle: "这里的景区正在整理")
        }
        .navigationTitle(province)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DestinationResults: View {
    let results: [Destination]
    let query: String
    let emptyTitle: String

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "map")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(results) { DestinationLink(place: $0, query: query) }
            }
        }
    }
}
