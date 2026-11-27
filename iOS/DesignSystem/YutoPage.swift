import SwiftUI

struct YutoPage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18, content: content)
                .frame(maxWidth: 720)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(YutoTheme.paper.ignoresSafeArea())
        .foregroundStyle(YutoTheme.ink)
    }
}
