import Foundation

/// Fetches a resource from the modern web, trying candidate URLs in order
/// (HTTPS-upgraded first) and returning the first that answers.
nonisolated enum UpstreamFetcher {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // Cookies belong to the vintage browser, not to this proxy.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    static func fetch(_ request: HTTPRequest, trying candidates: [URL]) async throws -> UpstreamResponse {
        var lastError: Error = ProxyError.badRequest
        for candidate in candidates {
            do {
                return try await fetch(request, at: candidate)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// One request to one URL, redirects not followed.
    static func fetch(_ request: HTTPRequest, at url: URL,
                      forArchive: Bool = false) async throws -> UpstreamResponse {
        let upstream = UpstreamRequestBuilder.request(for: url, from: request,
                                                      forArchive: forArchive)
        let (body, response) = try await session.data(for: upstream, delegate: PassThroughRedirects())
        guard let http = response as? HTTPURLResponse else { throw ProxyError.badRequest }
        return UpstreamResponse(response: http, body: body, url: url)
    }
}
