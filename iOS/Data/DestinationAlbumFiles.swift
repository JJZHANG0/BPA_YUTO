import Foundation

enum DestinationAlbumFiles {
    static func folder(for destinationID: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "DestinationAlbums", directoryHint: .isDirectory)
            .appending(path: destinationID, directoryHint: .isDirectory)
    }

    static func photos(for destinationID: String) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder(for: destinationID),
                                                                   includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
