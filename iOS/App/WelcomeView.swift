import SwiftUI

struct WelcomeView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var mastheadWidth: CGFloat = 254
    let onStart: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image("TravelEmblem")
                            .resizable()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text("悠途 YUTO").font(.system(.title2, design: .serif, weight: .semibold))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("悠途 YUTO")
                    VStack(spacing: 16) {
                        if typeSize.isAccessibilitySize {
                            Text("和家人一起，轻松去旅行")
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                        } else {
                            Image("WelcomeTitle")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: mastheadWidth)
                                .accessibilityLabel("和家人一起，轻松去旅行")
                                .accessibilityAddTraits(.isHeader)
                        }
                        Text("为长辈设计的智能旅行平台\n规划更省心，出行更安心")
                            .font(.body.weight(.medium))
                            .lineSpacing(4)
                    }
                    .padding(.top, verticalSizeClass == .compact ? 20 : 40)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(YutoTheme.ink)
                .padding(.horizontal, 22)
                .padding(.top, verticalSizeClass == .compact || typeSize.isAccessibilitySize ? 12 : min(70, proxy.size.height * 0.09))
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .background {
                    if typeSize.isAccessibilitySize || verticalSizeClass == .compact {
                        YutoTheme.paper.opacity(0.9).ignoresSafeArea(edges: .top)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Button(action: onStart) {
                    HStack(spacing: 14) {
                        Text("开启悠途之旅")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: 330)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(YutoTheme.forest.gradient, in: Capsule())
                    .overlay { Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.24), radius: 7, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("start-journey")
                .padding(.horizontal, 30)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .background {
            GeometryReader { proxy in
                Image("WelcomeLake")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
        }
    }
}
