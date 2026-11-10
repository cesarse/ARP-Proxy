import Foundation

/// Builds the URLSession request that impersonates the vintage browser.
nonisolated enum UpstreamRequestBuilder {
    /// Hop-by-hop and modern-protocol request headers, never forwarded.
    private static let droppedHeaders: Set<String> = [
        "connection", "proxy-connection", "proxy-authorization", "keep-alive",
        "te", "trailer", "transfer-encoding", "upgrade",
        "accept-encoding", "host", "content-length", "upgrade-insecure-requests",
    ]

    /// Headers addressed to the original site, never sent to the Internet
    /// Archive: its cookies and credentials are no business of the archive,
    /// and cache validators could have been issued for a capture from
    /// another date — a 304 would then pin the browser to the wrong period.
    private static let archiveDroppedHeaders: Set<String> = [
        "cookie", "authorization", "referer",
        "if-modified-since", "if-none-match", "if-match", "if-unmodified-since", "if-range",
    ]

    static func request(for url: URL, from request: HTTPRequest,
                        forArchive: Bool = false) -> URLRequest {
        var upstream = URLRequest(url: url)
        upstream.httpMethod = request.method
        for header in request.headers {
            let name = header.name.lowercased()
            if droppedHeaders.contains(name) { continue }
            if forArchive, archiveDroppedHeaders.contains(name) { continue }
            upstream.addValue(header.value, forHTTPHeaderField: header.name)
        }
        if !request.body.isEmpty {
            upstream.httpBody = request.body
        }
        return upstream
    }
}
