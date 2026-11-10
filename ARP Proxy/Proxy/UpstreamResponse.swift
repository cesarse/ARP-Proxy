import Foundation

/// What came back from the modern web — or the Wayback Machine: the
/// response, its body, and the URL that finally answered (which may be the
/// HTTPS-upgraded one, or an archive snapshot).
nonisolated struct UpstreamResponse: Sendable {
    let response: HTTPURLResponse
    let body: Data
    let url: URL
    /// The capture's `YYYYMMDDhhmmss` timestamp when the response came from
    /// the Wayback Machine.
    var archivedAt: String? = nil

    var contentType: String {
        (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
    }

    var usedHTTPS: Bool {
        url.scheme == "https"
    }
}
