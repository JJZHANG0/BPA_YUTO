import SwiftUI

enum YutoTheme {
    static let ink = color(0x19312D, highContrast: 0x071713)
    static let sage = color(0x246B63, highContrast: 0x0A493F)
    static let forest = sage
    static let paper = color(0xF7F5EF, highContrast: 0xFFFFFF)
    static let amber = color(0xD99045)
    static let amberInk = color(0x814818, highContrast: 0x5F2D07)
    static let amberSurface = color(0xF8E9D7)
    static let mist = color(0xE6F1EC)
    static let greyGreen = color(0xC9D7CF)
    static let neutralGreen = color(0x8FA39B)
    static let porcelain = color(0xFFFEFA)
    static let muted = color(0x4E625D, highContrast: 0x233C35)
    static let divider = color(0xD9E1DA, highContrast: 0x72837B)
    static let round: CGFloat = 16

    private static func color(_ rgb: UInt32, highContrast: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.accessibilityContrast == .high ? highContrast ?? rgb : rgb
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

struct YutoSection: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.title2, design: .serif, weight: .bold)).accessibilityAddTraits(.isHeader)
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
            .background(primary ? AnyShapeStyle(YutoTheme.forest.gradient) : AnyShapeStyle(YutoTheme.porcelain), in: Capsule())
            .overlay { Capsule().strokeBorder(primary ? .clear : YutoTheme.greyGreen) }
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
        .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(YutoTheme.divider) }

    }
}

struct YutoArtwork: View {
    let name: String
    var ext = "png"

    var body: some View {
        if let image = UIImage(named: "\(name).\(ext)") {
            Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

struct YutoScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.largeTitle, design: .serif, weight: .bold))
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
            let path = [subdirectory, "\(name).jpg"].compactMap { $0 }.joined(separator: "/")
            if let image = UIImage(named: path) ?? UIImage(named: name) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                YutoTheme.mist
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


struct YutoAssistantMark: View {
    var body: some View {
        Image("TravelAssistant").resizable().scaledToFit().accessibilityHidden(true)
    }
}
