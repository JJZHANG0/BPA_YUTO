import SwiftUI

enum YutoTheme {
    static let ink = Color(white: 0.08)
    static let sage = Color(red: 0.10, green: 0.27, blue: 0.23)
    static let forest = Color(white: 0.10)
    static let paper = Color.white
    static let mist = Color(white: 0.958)
    static let porcelain = Color.white
    static let muted = Color(white: 0.34)
    static let divider = Color(white: 0.89)
    static let round: CGFloat = 12
}

struct YutoSection: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            if let detail { Text(detail).font(.subheadline).foregroundStyle(YutoTheme.muted) }
        }
    }
}

struct YutoButtonStyle: ButtonStyle {
    var primary = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 48)
            .foregroundStyle(primary ? .white : YutoTheme.forest)
            .background(primary ? YutoTheme.forest : YutoTheme.mist, in: RoundedRectangle(cornerRadius: 9))
            .opacity(!enabled ? 0.48 : configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct YutoSearchField: View {
    @Binding var query: String
    var hint: String
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(YutoTheme.sage).accessibilityHidden(true)
            TextField("搜索目的地", text: $query,
                      prompt: Text(hint).foregroundStyle(YutoTheme.muted))
                .foregroundStyle(YutoTheme.ink)
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
                .accessibilityIdentifier("destination-search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(YutoTheme.sage)
                        .frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("清空搜索")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
        .background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 9))

    }
}

struct YutoArtwork: View {
    let name: String
    var ext = "png"

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: ext),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

struct YutoScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.body).foregroundStyle(YutoTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct YutoPhoto: View {
    let name: String
    var subdirectory: String? = nil

    var body: some View {
        GeometryReader { proxy in
            if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: subdirectory),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                YutoTheme.mist
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
