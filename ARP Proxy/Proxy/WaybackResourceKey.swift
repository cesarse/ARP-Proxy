import Foundation

/// The identity the Wayback Machine files a capture under. Its index ignores
/// the scheme, a leading `www.`, default ports, letter case and query order,
/// so URLs that differ only in those ways are one archived resource.
///
/// This decides which archive redirects the proxy follows itself: a redirect
/// to the same resource must never reach the browser, because the browser
/// would ask for it again and the archive would answer with the same
/// redirect — a loop. A redirect to a different resource (even `/a` → `/a/`)
/// must reach the browser, or relative links on the page resolve wrongly.
nonisolated struct WaybackResourceKey: Equatable, Sendable {
    private let value: String

    init(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var host = (components?.percentEncodedHost ?? "").lowercased()
        if let range = host.range(of: #"^www\d*\."#, options: .regularExpression) {
            host.removeSubrange(range)
        }
        var authority = host
        if let port = components?.port, port != 80, port != 443 {
            authority += ":\(port)"
        }
        var path = components?.percentEncodedPath ?? ""
        if path.isEmpty {
            path = "/"
        }
        var key = authority + path
        if let query = components?.percentEncodedQuery, !query.isEmpty {
            key += "?" + query.split(separator: "&").sorted().joined(separator: "&")
        }
        value = key.lowercased()
    }
}
