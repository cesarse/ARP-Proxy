import Foundation

/// What came back from the modern web: the response, its body, and the URL
/// that finally answered (which may be the HTTPS-upgraded one).
nonisolated struct UpstreamResponse: Sendable {
    let response: HTTPURLResponse
    let body: Data
    let url: URL

    var contentType: String {
        (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
    }

    var usedHTTPS: Bool {
        url.scheme == "https"
    }
}
