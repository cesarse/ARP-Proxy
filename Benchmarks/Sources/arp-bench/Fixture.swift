import Foundation

/// One frozen capture from the real web, with the Content-Type it arrived
/// with — `HTMLInputDecoder` reads that header, so a fixture without it would
/// be decoded differently than in production.
///
/// Fixtures are committed snapshots rather than live fetches on purpose: CNN's
/// homepage changes hourly, and a benchmark that re-fetched could not tell a
/// regression from a news cycle. Refresh them with `capture-fixtures.sh`.
nonisolated struct Fixture: Sendable {
    let name: String
    let url: String
    let contentType: String
    let note: String
    let body: Data

    /// Reads every fixture named in the manifest, in the order listed there.
    static func load(from directory: URL) throws -> [Fixture] {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let entries = try JSONDecoder().decode(
            [Entry].self, from: Data(contentsOf: manifestURL))
        return try entries.map { entry in
            let bodyURL = directory.appendingPathComponent("\(entry.name).html")
            return Fixture(name: entry.name, url: entry.url,
                           contentType: entry.contentType, note: entry.note,
                           body: try Data(contentsOf: bodyURL))
        }
    }

    private struct Entry: Decodable {
        let name: String
        let url: String
        let contentType: String
        let note: String
    }
}
