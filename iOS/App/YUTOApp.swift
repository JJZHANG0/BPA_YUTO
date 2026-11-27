import SwiftUI

@main
struct YUTOApp: App {
    private let defaults: UserDefaults
    @State private var store: TravelStore

    init() {
        let defaults = Self.applicationDefaults
        self.defaults = defaults
        let preferences = TravelPreferences(defaults: defaults)
        _store = State(initialValue: TravelStore(catalog: try? BundledCatalogRepository.load(), preferences: preferences))
    }

    var body: some Scene {
        WindowGroup {
            YutoEntryView()
                .background(TravelContrastPreference(increased: store.profile.highContrast == true))
                .environment(store)
                .tripReminderDelivery(store: store)
                .defaultAppStorage(defaults)
                .preferredColorScheme(.light)
                .tint(YutoTheme.forest)
                .dynamicTypeSize((store.profile.extraLargeText == true ? DynamicTypeSize.accessibility1 : store.profile.largerText ? .xLarge : .xSmall) ... .accessibility5)
        }
    }

    private static var applicationDefaults: UserDefaults {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["YUTO_UI_TEST_SUITE"],
           suite.hasPrefix("yuto.ui-test."), let defaults = UserDefaults(suiteName: suite) {
            return defaults
        }
        #endif
        return .standard
    }
}

private struct YutoEntryView: View {
    @AppStorage("yuto.native.didEnterTravel") private var didEnterTravel = false

    var body: some View {
        if didEnterTravel {
            YutoTabs()
        } else {
            WelcomeView { didEnterTravel = true }
        }
    }
}
