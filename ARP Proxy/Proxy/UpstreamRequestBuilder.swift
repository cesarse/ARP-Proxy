import Foundation

/// Builds the URLSession request that impersonates the vintage browser.
nonisolated enum UpstreamRequestBuilder {
    /// Hop-by-hop and modern-protocol request headers, never forwarded.
    private static let droppedHeaders: Set<String> = [
        "connection", "proxy-connection", "proxy-authorization", "keep-alive",
        "te", "trailer", "transfer-encoding", "upgrade",
        "accept-encoding", "host", "content-length", "upgrade-insecure-requests",
    ]

    static func request(for url: URL, from request: HTTPRequest) -> URLRequest {
        var upstream = URLRequest(url: url)
        upstream.httpMethod = request.method
        for header in request.headers
        where !droppedHeaders.contains(header.name.lowercased()) {
            upstream.addValue(header.value, forHTTPHeaderField: header.name)
        }
        if !request.body.isEmpty {
            upstream.httpBody = request.body
        }
        return upstream
    }
}
