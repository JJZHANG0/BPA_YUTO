import SwiftUI

struct ScenicDestinationCard: View {
    let place: Destination
    let caption: String
    var wide = false
    @Environment(TravelStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 165

    var body: some View {
        let title = wide ? "\(place.province) · \(place.shortName)" : place.shortName
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                DestinationDetailView(place: place, query: "")
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer(minLength: 56)
                    Text(title)
                        .font(.system(wide ? .title : .title3, design: .serif, weight: .bold))
                    Text(caption).font(.footnote.weight(.medium))
                }
                .padding(wide ? 18 : 12)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: cardHeight * (wide ? 1.20 : 1), alignment: .bottomLeading)
                .background {
                    if let name = place.featuredArtwork {
                        YutoPhoto(name: name + "Cover")
                            .overlay(LinearGradient(stops: [
                                .init(color: .clear, location: 0.30),
                                .init(color: Color.black.opacity(0.16), location: 0.54),
                                .init(color: Color.black.opacity(0.79), location: 1)
                            ], startPoint: .top, endPoint: .bottom))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.shortName)，\(caption)")
            Button { store.toggleFavorite(place.id) } label: {
                Image(systemName: store.favorites.contains(place.id) ? "heart.fill" : "heart")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(store.favorites.contains(place.id) ? YutoTheme.sage : Color.black.opacity(0.5), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(store.favorites.contains(place.id) ? "取消收藏" : "收藏")\(place.shortName)")
            .padding(2)
        }
    }
}
