import SwiftUI

struct DestinationLink: View {
    let place: Destination
    var query = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationLink { DestinationDetailView(place: place, query: query) } label: {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    thumbnail
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(typeSize.isAccessibilitySize ? place.name : place.shortName).font(.headline)
                        .accessibilityLabel(place.name)
                    Text("\(place.city) · \(place.grade) 景区")
                        .font(.subheadline).foregroundStyle(YutoTheme.muted)
                    if let caption = place.scoreCaption {
                        Label(caption, systemImage: "star.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(YutoTheme.amberInk)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.subheadline.weight(.medium))
                    .foregroundStyle(YutoTheme.sage).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(10)
            .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(YutoTheme.divider) }
            .contentShape(.rect)
            .foregroundStyle(YutoTheme.ink)
        }.buttonStyle(.plain)
    }

    private var thumbnail: some View {
        let provinceCover = ProvinceIllustration.photo(for: place.province)
        return YutoPhoto(name: place.featuredArtwork ?? provinceCover.name,
                         subdirectory: place.featuredArtwork == nil ? provinceCover.folder : nil)
            .frame(width: 72, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
