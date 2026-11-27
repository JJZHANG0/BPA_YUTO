import SwiftUI

struct HomeView: View {
    let catalog: Catalog
    let visitedCount: Int
    @Binding var query: String
    let search: () -> Void
    let plan: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var highlights: [Destination] {
        catalog.attractions.filter { $0.featuredArtwork != nil }
            .sorted { ($0.previewScore ?? 0) > ($1.previewScore ?? 0) }
    }

    var body: some View {
        YutoPage {
            VStack(alignment: .leading, spacing: 12) {
                HomeWeatherBar()
                YutoScreenTitle(title: "今天，想去哪里走走？")
                searchRow
            }

            if let first = highlights.first, let photo = first.featuredArtwork {
                featured(first, photo: photo)
            }

            exploreLink

            if highlights.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        YutoSection(title: "精选目的地")
                        Spacer(minLength: 6)
                        Button("规划行程", action: plan)
                            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }
                    ForEach(highlights.dropFirst()) { place in
                        Divider()
                        DestinationLink(place: place)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var searchRow: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            YutoSearchField(query: $query, hint: "城市或旅行需求", onSubmit: search)
            Button("搜索", action: search).buttonStyle(YutoButtonStyle())
        }
    }

    private func featured(_ place: Destination, photo: String) -> some View {
        NavigationLink {
            DestinationDetailView(place: place, query: "")
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                YutoPhoto(name: photo)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.shortName).font(.title2.weight(.semibold)).foregroundStyle(YutoTheme.ink)
                        if let caption = place.scoreCaption {
                            Text(caption).font(.subheadline).foregroundStyle(YutoTheme.muted)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.body.weight(.medium)).foregroundStyle(YutoTheme.sage).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var exploreLink: some View {
        Button {
            query = ""
            search()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("点亮中国").font(.headline)
                    } icon: {
                        Image(systemName: "sun.max.fill").foregroundStyle(YutoTheme.amberInk)
                    }
                    Text("已走过 \(visitedCount) / \(catalog.provinces.count) 个省级地区")
                        .font(.subheadline).foregroundStyle(YutoTheme.muted)
                }
                Spacer(minLength: 4)
                if !typeSize.isAccessibilitySize {
                    YutoArtwork(name: "ExplorationMap").frame(width: 88, height: 46)
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
            }
            .padding(13)
            .frame(minHeight: 58)
            .foregroundStyle(YutoTheme.ink)
            .background(YutoTheme.amberSurface, in: RoundedRectangle(cornerRadius: YutoTheme.round))
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开省份目录。标记行程完成后点亮对应地区。")
        .accessibilityIdentifier("explore-provinces")
    }
}
