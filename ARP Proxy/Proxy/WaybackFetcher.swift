import Foundation

/// Fetches a URL as the Wayback Machine archived it near a timestamp,
/// following the archive's own "nearest capture" redirects until a capture
/// (or a redirect the original site made back then) is reached.
nonisolated enum WaybackFetcher {
    /// A lookup usually settles in one or two hops; the bound only stops a
    /// capture that redirects to itself from looping forever.
    private static let maxHops = 10

    static func fetch(_ request: HTTPRequest, original: URL,
                      timestamp: String) async throws -> UpstreamResponse {
        guard var next = WaybackSnapshot(original: original, timestamp: timestamp).url else {
            throw WaybackError.notArchived
        }
        for _ in 0..<maxHops {
            let answer = try await UpstreamFetcher.fetch(request, at: next, forArchive: true)
            switch WaybackAnswer.interpret(answer.response, requested: original) {
            case .follow(let snapshot):
                next = snapshot
            case .deliver(let response):
                return UpstreamResponse(response: response, body: answer.body, url: next,
                                        archivedAt: WaybackSnapshot(parsing: next.absoluteString)?.timestamp)
            case .fail(let error):
                throw error
            }
        }
        throw WaybackError.tooManyRedirects
    }
}
