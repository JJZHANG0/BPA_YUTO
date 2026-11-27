import SwiftUI

struct YutoTabs: View {
    private enum HomeRoute: Hashable { case planner, footprints, assistance }

    @Environment(TravelStore.self) private var store
    @State private var tab = Tab.home
    @State private var homeQuery = ""
    @State private var discoverQuery = ""
    @State private var homePath = NavigationPath()
    @State private var discoverPath = NavigationPath()
    @State private var presentation = TripPresentation()

    var body: some View {
        @Bindable var presentation = presentation
        Group {
            if let catalog = store.catalog {
                let visited = store.visitedProvinces(in: catalog)
                TabView(selection: $tab) {
                    NavigationStack(path: $homePath) {
                        HomeView(catalog: catalog, visitedCount: visited.count, query: $homeQuery,
                                 search: searchFromHome, plan: { homePath.append(HomeRoute.planner) },
                                 trips: { tab = .trips }, family: { tab = .family },
                                 footprints: { homePath.append(HomeRoute.footprints) },
                                 assistance: { homePath.append(HomeRoute.assistance) })
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .planner: PlannerView(catalog: catalog)
                                case .footprints: FootprintsView(catalog: catalog)
                                case .assistance: TravelHelpView()
                                }
                            }
                    }
                    .tabItem { Label(Tab.home.rawValue, systemImage: Tab.home.icon) }.tag(Tab.home)
                    NavigationStack(path: $discoverPath) {
                        DiscoverView(catalog: catalog, profile: store.profile, visited: visited, query: $discoverQuery)
                    }
                    .tabItem { Label(Tab.discover.rawValue, systemImage: Tab.discover.icon) }.tag(Tab.discover)
                    NavigationStack { TripsView(catalog: catalog) }
                        .tabItem { Label(Tab.trips.rawValue, systemImage: Tab.trips.icon) }.tag(Tab.trips)
                    NavigationStack { FamilyView(catalog: catalog) }
                        .tabItem { Label(Tab.family.rawValue, systemImage: Tab.family.icon) }.tag(Tab.family)
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
    }

    private func searchFromHome() {
        discoverPath = NavigationPath()
        discoverQuery = homeQuery
        tab = .discover
    }
}
