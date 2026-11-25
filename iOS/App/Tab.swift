import Foundation

enum Tab: String, CaseIterable {
    case home = "首页", discover = "发现", trips = "行程", profile = "我的"

    var icon: String {
        switch self {
        case .home: "house"
        case .discover: "safari"
        case .trips: "calendar"
        case .profile: "person.crop.circle"
        }
    }
}
