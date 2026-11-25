import SwiftUI

struct DestinationLink: View {
    let place: Destination
    var query = ""

    var body: some View {
        NavigationLink { DestinationDetailView(place: place, query: query) } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 5) {
                    Text(place.shortName).font(.headline)
                        .accessibilityLabel(place.name)
                    Text("\(place.city) · \(place.grade) 景区").font(.subheadline).foregroundStyle(YutoTheme.muted)
                    if let caption = place.scoreCaption {
                        Text(caption).font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.sage)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.footnote).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.vertical, 8)
            .contentShape(.rect)
            .foregroundStyle(YutoTheme.ink)
        }.buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let name = place.featuredArtwork,
           let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 76, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "mountain.2").font(.title2).foregroundStyle(YutoTheme.sage)
                .frame(width: 54, height: 54).background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }
}
