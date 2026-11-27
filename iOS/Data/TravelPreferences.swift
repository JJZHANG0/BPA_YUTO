import Foundation

struct TravelPreferences {
    var defaults: UserDefaults = .standard

    enum Key: String {
        case profile = "yuto.native.profile"
        case trips = "yuto.native.trips"
        case reviews = "yuto.native.destinationReviews"
        case manualFootprints = "yuto.native.manualFootprints"
        case favorites = "yuto.native.favorites"
        case companions = "yuto.native.companions"
    }

    func load<Value: Decodable>(_ key: Key, default fallback: Value) -> Value {
        guard let data = defaults.data(forKey: key) else { return fallback }
        return (try? JSONDecoder().decode(Value.self, from: data)) ?? fallback
    }

    func save<Value: Encodable>(_ value: Value, for key: Key) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }
}

private extension UserDefaults {
    func data(forKey key: TravelPreferences.Key) -> Data? {
        data(forKey: key.rawValue)
    }
}

enum TripAlbumFiles {
    static func directory(for tripID: UUID) -> URL {
        URL.applicationSupportDirectory.appending(path: "TripAlbums", directoryHint: .isDirectory)
            .appending(path: tripID.uuidString, directoryHint: .isDirectory)
    }

    static func items(for tripID: UUID) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory(for: tripID), includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
