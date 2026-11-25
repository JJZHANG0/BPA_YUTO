import SwiftUI

@main
struct YUTOApp: App {
    @State private var store = makeStore()

    var body: some Scene {
        WindowGroup {
            YutoTabs().environment(store)
        }
    }

    private static func makeStore() -> TravelStore {
        let catalog = try? BundledCatalogRepository.load()
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["YUTO_UI_TEST_SUITE"],
           suite.hasPrefix("yuto.ui-test."), let defaults = UserDefaults(suiteName: suite) {
            return TravelStore(catalog: catalog, preferences: TravelPreferences(defaults: defaults))
        }
        #endif
        return TravelStore(catalog: catalog)
    }
}
