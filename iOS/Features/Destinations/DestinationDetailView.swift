import SwiftUI

struct DestinationDetailView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    @Environment(\.dynamicTypeSize) private var typeSize
    let place: Destination
    let query: String

    private var saved: Bool { store.favorites.contains(place.id) }
    private var priorities: Set<String> {
        DestinationMatcher.neededDimensions(query: query, profile: store.profile)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DestinationGallery(place: place)
                VStack(alignment: .leading, spacing: 18) {
                    overview
                    visitAdvice
                    Button {
                        presentation.editing = Trip(destination: place.id, slow: store.profile.slowPace)
                    } label: {
                        Label("加入行程", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle())

                    DestinationVisitTags(place: place, priorities: priorities)
                    DestinationReviews(place: place)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .ignoresSafeArea(.container, edges: .top)
        .background(YutoTheme.paper)
        .foregroundStyle(YutoTheme.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { store.toggleFavorite(place.id) } label: {
                    Image(systemName: saved ? "heart.fill" : "heart")
                }
                .accessibilityLabel(saved ? "已收藏" : "收藏景区")
                .accessibilityHint(saved ? "点按取消收藏" : "收藏后可在我的页面查看")
                .sensoryFeedback(.selection, trigger: saved)
                ShareLink(item: "\(place.name) · \(place.city)\n\(place.notice)") {
                    Image(systemName: "square.and.arrow.up")
                }.accessibilityLabel("分享给家人")
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { location; Spacer(); seasonalHighlight }
                VStack(alignment: .leading, spacing: 6) { location; seasonalHighlight }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(YutoTheme.muted)
            Divider().overlay(YutoTheme.divider)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { overviewTitle; Spacer(); overviewRating }
                VStack(alignment: .leading, spacing: 6) { overviewTitle; overviewRating }
            }
            let items = [
                ("figure.walk", "游览方式", place.walkingGuide.style),
                ("leaf", "行程节奏", store.profile.slowPace ? "慢游多歇" : "按需安排")
            ]
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(items, id: \.0) { icon, title, value in
                    HStack(spacing: 9) {
                        Image(systemName: icon).font(.title3).foregroundStyle(YutoTheme.forest)
                            .frame(width: 34, height: 40)
                            .background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.caption).foregroundStyle(YutoTheme.muted)
                            Text(value).font(.subheadline.weight(.semibold))
                        }
                    }.accessibilityElement(children: .combine)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(YutoTheme.divider) }
    }

    private var location: some View {
        Label("\(place.province) · \(place.city)", systemImage: "mappin.and.ellipse")
    }

    @ViewBuilder private var seasonalHighlight: some View {
        switch place.featuredArtwork {
        case "WestLake":
            // Hangzhou autumn osmanthus guide: https://ori.hangzhou.com.cn/ornews/content/2026-10/09/content_9331319.htm
            Label("秋日赏桂", systemImage: "leaf")
        case "SuzhouGarden":
            // Suzhou Gardens Administration: https://ylj.suzhou.gov.cn/szsylj/sjyc/201905/c1df393edc8745abb20e8a9bd5525782.shtml
            Label("春看杜鹃 · 夏赏荷", systemImage: "leaf")
        default:
            EmptyView()
        }
    }

    private var overviewTitle: some View {
        Text(place.score != nil || place.previewScore != nil ? "适老友好度" : "适老游览参考")
            .font(.headline).accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var overviewRating: some View {
        if let value = place.score ?? place.previewScore {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "star.fill").foregroundStyle(YutoTheme.amber).font(.subheadline)
                Text("\(value)").font(.title3.bold()).monospacedDigit()
                Text(place.score == nil ? "分 · 预估" : "分").font(.subheadline).foregroundStyle(YutoTheme.muted)
            }.accessibilityElement(children: .combine)
        }
    }

    private var visitAdvice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("适老游览建议", systemImage: "sparkles")
                .font(.headline).foregroundStyle(YutoTheme.amberInk)
                .accessibilityAddTraits(.isHeader)
            Text(place.walkingGuide.advice).font(.body).fixedSize(horizontal: false, vertical: true)
            TravelReadButton(text: place.shortName + "。" + place.walkingGuide.advice)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(YutoTheme.amberSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension Destination {
    fileprivate var walkingGuide: (style: String, advice: String) {
        switch featuredArtwork {
        case "WestLake":
            return ("沿湖漫步", "沿湖选一段喜欢的岸线慢慢走。累了就原路返回，把环湖留给下一次。")
        case "SuzhouGarden":
            return ("分园游赏", "拙政园、留园、虎丘可以分开游览。一次选一处园子，遇到台阶或石桥时，先看清落脚处。")
        case "Gulangyu":
            return ("街巷慢行", "上岛前和家人约好返程码头。把想去的街巷挑出一两条，给停步休息和返程留足时间。")
        default:
            if ["古镇", "古城", "古商城", "府城", "古文化", "大院", "古迹"].contains(where: name.contains) {
                return ("街巷慢行", "先选一条主街慢慢逛，经过石板路和门槛时留心脚下。和家人约好会合处，逛累了就回去歇脚。")
            }
            if ["湖", "湿地", "运河", "海滩", "海洋", "河口", "江湾"].contains(where: name.contains) {
                return ("水畔散步", "挑一段喜欢的岸线作为往返路线，出门先约好折返点。沿途留意座椅的位置，方便回程休息。")
            }
            if ["山", "峡", "梯田", "丹霞", "长城", "峰"].contains(where: name.contains) {
                return ("分段赏景", "先在入口看看路线图，把最想看的景观点放在前面。遇到较长爬坡时，可以只走一段再原路返回。")
            }
            return ("分段游览", "先和同行的人挑一处最想看的风景。从入口安排一段短路线，在折返点歇一歇，再决定是否继续。")
        }
    }
}

private struct DestinationVisitTags: View {
    let place: Destination
    let priorities: Set<String>
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Tag: Identifiable {
        let dimension: String
        let title: String
        let icon: String
        var id: String { dimension }
    }

    private var tags: [Tag] {
        let choices = [
            Tag(dimension: "步行及体力负担", title: place.walkingGuide.style, icon: "figure.walk"),
            Tag(dimension: "休息设施", title: "预留休息", icon: "cup.and.saucer"),
            Tag(dimension: "交通便利性", title: "规划返程", icon: "bus"),
            Tag(dimension: "无障碍便利性", title: "提前问路况", icon: "figure.roll")
        ]
        return choices.filter { priorities.contains($0.id) } + choices.filter { !priorities.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            YutoSection(title: "行前小贴士")
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(tags) { tag in
                    Label(tag.title, systemImage: tag.icon)
                        .font(.body.weight(.medium)).foregroundStyle(YutoTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(tagColor(tag), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            let details = place.dimensions.compactMap { dimension in dimension.score.map { "\(dimension.name) \($0) 分" } }
            if !details.isEmpty {
                Text(details.joined(separator: " · ")).font(.subheadline).foregroundStyle(YutoTheme.muted)
            }
        }
    }

    private func tagColor(_ tag: Tag) -> Color {
        switch tag.dimension {
        case "休息设施": YutoTheme.amberSurface
        case "交通便利性": YutoTheme.sage.opacity(0.13)
        case "无障碍便利性": YutoTheme.divider.opacity(0.76)
        default: YutoTheme.mist
        }
    }
}
