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

struct PlaceImage: View {
    let place: Destination
    var body: some View {
        if let name = place.featuredArtwork { YutoPhoto(name: name) }
        else {
            let cover = ProvinceIllustration.photo(for: place.province)
            YutoPhoto(name: cover.name, subdirectory: cover.folder)
        }
    }
}

struct TravelCover: View {
    let place: Destination?
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Spacer(minLength: 48)
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.subheadline.weight(.medium))
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 138, alignment: .bottomLeading)
        .foregroundStyle(.white)
        .background {
            ZStack {
                if let name = place?.featuredArtwork { YutoPhoto(name: name + "Cover") }
                else if let place { PlaceImage(place: place) }
                else { YutoPhoto(name: "Jiangnan") }
                LinearGradient(colors: [.clear, .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

extension View {
    func travelPanel(_ inset: CGFloat = 16) -> some View {
        padding(inset)
            .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(YutoTheme.divider, lineWidth: 0.7) }
    }
}

struct TravelMenuRow: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3.weight(.medium)).foregroundStyle(YutoTheme.sage)
                .frame(width: 42, height: 42).background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(YutoTheme.muted)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(YutoTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
