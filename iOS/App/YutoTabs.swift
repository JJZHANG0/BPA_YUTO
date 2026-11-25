import SwiftUI

struct YutoTabs: View {
    @Environment(TravelStore.self) private var store
    @State private var tab = Tab.home
    @State private var homeQuery = ""
    @State private var discoverQuery = ""
    @State private var discoverPath = NavigationPath()
    @State private var presentation = TripPresentation()

    var body: some View {
        @Bindable var presentation = presentation
        Group {
            if let catalog = store.catalog {
                let visited = catalog.visitedProvinces(in: store.trips)
                TabView(selection: $tab) {
                    NavigationStack {
                        HomeView(catalog: catalog, visitedCount: visited.count, query: $homeQuery,
                                 search: searchFromHome, plan: { tab = .trips })
                    }
                    .tabItem { Label(Tab.home.rawValue, systemImage: Tab.home.icon) }.tag(Tab.home)
                    NavigationStack(path: $discoverPath) {
                        DiscoverView(catalog: catalog, profile: store.profile, visited: visited, query: $discoverQuery)
                    }
                    .tabItem { Label(Tab.discover.rawValue, systemImage: Tab.discover.icon) }.tag(Tab.discover)
                    NavigationStack { TripsView(catalog: catalog) }
                        .tabItem { Label(Tab.trips.rawValue, systemImage: Tab.trips.icon) }.tag(Tab.trips)
                    NavigationStack { ProfileView(catalog: catalog) }
                        .tabItem { Label(Tab.profile.rawValue, systemImage: Tab.profile.icon) }.tag(Tab.profile)
                }
                .sheet(item: $presentation.editing) { trip in
                    TripEditor(trip: trip, catalog: catalog) { updated in
                        store.saveTrip(updated)
                        presentation.editing = nil
                    }
                }
            } else {
                ContentUnavailableView("景区目录未能打开", systemImage: "map", description: Text("请重新安装悠途后再试。"))
            }
        }
        .environment(presentation)
        .tint(YutoTheme.sage)
        .preferredColorScheme(.light)
        .dynamicTypeSize(store.profile.largerText ? .xLarge ... .accessibility5 : .xSmall ... .accessibility5)
    }

    private func searchFromHome() {
        discoverPath = NavigationPath()
        discoverQuery = homeQuery
        tab = .discover
    }
}
