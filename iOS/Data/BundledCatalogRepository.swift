import Foundation

enum BundledCatalogRepository {
    static func load(bundle: Bundle = .main) throws -> Catalog {
        guard let url = bundle.url(forResource: "Catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }
}
