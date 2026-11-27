import SwiftUI

struct DestinationDetailView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    let place: Destination
    let query: String

    private var saved: Bool { store.favorites.contains(place.id) }

    var body: some View {
        YutoPage {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(place.province) · \(place.city) · \(place.grade) 景区")
                    .font(.subheadline).foregroundStyle(YutoTheme.muted)
                YutoScreenTitle(title: place.name)
                if let caption = place.scoreCaption {
                    Text(caption).font(.subheadline.weight(.semibold))
                        .foregroundStyle(YutoTheme.amberInk)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(YutoTheme.amberSurface, in: Capsule())
                }
            }
            DestinationGallery(place: place)
            actions
            DestinationVisitTags(place: place, priorities: DestinationMatcher.neededDimensions(query: query, profile: store.profile))
            DestinationReviews(place: place)
        }
        .navigationTitle("景区详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                presentation.editing = Trip(destination: place.id, slow: store.profile.slowPace)
            } label: {
                Label("加入行程", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
            }.buttonStyle(YutoButtonStyle())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { favoriteButton; shareButton }
                VStack(alignment: .leading, spacing: 8) { favoriteButton; shareButton }
            }.buttonStyle(YutoButtonStyle(primary: false))
        }
    }

    private var favoriteButton: some View {
        Button { store.toggleFavorite(place.id) } label: {
            Label(saved ? "已收藏" : "收藏景区", systemImage: saved ? "heart.fill" : "heart")
        }
        .accessibilityHint(saved ? "点按取消收藏" : "收藏后可在我的页面查看")
        .sensoryFeedback(.selection, trigger: saved)
    }

    private var shareButton: some View {
        ShareLink(item: "\(place.name) · \(place.city)\n\(place.notice)") {
            Label("分享给家人", systemImage: "square.and.arrow.up")
        }
    }
}

private struct DestinationVisitTags: View {
    let place: Destination
    let priorities: Set<String>
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Tag: Identifiable {
        let title: String
        let icon: String
        let color: Color
        var id: String { title }
    }

    private var tags: [Tag] {
        let walking: String
        if place.name.contains("鼓浪屿") {
            walking = "散步选短线"
        } else if place.name.contains("西湖") {
            walking = "湖边慢走"
        } else if place.name.contains("园林") || place.name.contains("古镇") {
            walking = "分段慢游"
        } else if place.name.contains("山") || place.name.contains("峡") || place.name.contains("梯田") {
            walking = "先查坡度"
        } else {
            walking = "先选短路线"
        }

        let choices: [(String, Tag)] = [
            ("步行及体力负担", Tag(title: walking, icon: "figure.walk", color: YutoTheme.mist)),
            ("休息设施", Tag(title: "预留休息", icon: "cup.and.saucer", color: YutoTheme.amberSurface)),
            ("交通便利性", Tag(title: "查返程交通", icon: "bus", color: Color(red: 0.87, green: 0.93, blue: 0.99))),
            ("无障碍便利性", Tag(title: "询问无障碍路线", icon: "figure.roll", color: Color(red: 0.94, green: 0.89, blue: 0.98)))
        ]
        return choices.filter { priorities.contains($0.0) }.map(\.1)
            + choices.filter { !priorities.contains($0.0) }.map(\.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                YutoSection(title: "怎么玩更轻松", detail: "出发前可参考的游览建议")
                Spacer(minLength: 8)
                if !typeSize.isAccessibilitySize {
                    YutoArtwork(name: "Compass").frame(width: 82, height: 60)
                }
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(tags) { tag in
                    Label(tag.title, systemImage: tag.icon)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(tag.color, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            let verified = place.dimensions.filter { $0.score != nil }
            if !verified.isEmpty {
                Text(verified.compactMap { dimension in dimension.score.map { "\(dimension.name) \($0) 分" } }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(YutoTheme.muted)
            }
        }
    }
}
