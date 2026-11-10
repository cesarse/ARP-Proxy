import Foundation

/// What one response from the Wayback Machine means for the browser. The
/// archive answers in three ways, and they look alike on the wire:
///
/// - a redirect to the nearest capture of the *same* resource (its
///   timestamp lookup): follow it here, the browser must never see it;
/// - a capture of a redirect the *original site* made back then: hand it
///   to the browser, translated to the original site's address;
/// - a capture: deliver it, minus everything that betrays the archive.
nonisolated enum WaybackAnswer {
    /// Fetch this snapshot next.
    case follow(URL)
    /// Send this to the browser; the body is the archive's, unchanged.
    case deliver(HTTPURLResponse)
    /// Show an error page instead.
    case fail(WaybackError)

    /// Archive-added response headers. In `id_` mode every original header
    /// is renamed `X-Archive-Orig-*`, so all `x-` headers are the archive's.
    private static let archiveHeaders: Set<String> = [
        "link", "memento-datetime", "server-timing", "set-cookie", "referrer-policy",
    ]

    static func interpret(_ response: HTTPURLResponse, requested original: URL) -> WaybackAnswer {
        let status = response.statusCode
        if (300..<400).contains(status),
           let location = response.value(forHTTPHeaderField: "Location"),
           let target = WaybackSnapshot(parsing: location, relativeTo: response.url) {
            if WaybackResourceKey(target.original) == WaybackResourceKey(original),
               let next = WaybackSnapshot(original: target.original, timestamp: target.timestamp).url {
                return .follow(next)
            }
            return .deliver(cleaned(response, location: browserFacing(target.original)))
        }
        // A capture carries Memento-Datetime — even a capture of a 404 the
        // site served back then. An error without it is the archive's own.
        if response.value(forHTTPHeaderField: "Memento-Datetime") == nil {
            if status == 429 { return .fail(.rateLimited) }
            if status >= 500 { return .fail(.unavailable(status: status)) }
            if status >= 400 { return .fail(.notArchived) }
        }
        return .deliver(cleaned(response, location: nil))
    }

    /// The address the vintage browser should go to next: plain http (the
    /// proxy upgrades nothing in Wayback mode, and old browsers can't do
    /// TLS anyway) and no explicit default port, which the archive adds.
    private static func browserFacing(_ original: URL) -> URL {
        guard var components = URLComponents(url: original, resolvingAgainstBaseURL: false)
        else { return original }
        components.scheme = "http"
        if components.port == 80 || components.port == 443 {
            components.port = nil
        }
        return components.url ?? original
    }

    private static func cleaned(_ response: HTTPURLResponse, location: URL?) -> HTTPURLResponse {
        var fields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String, let value = value as? String else { continue }
            let lower = name.lowercased()
            if lower.hasPrefix("x-") || archiveHeaders.contains(lower) { continue }
            if lower == "location", location != nil { continue }
            fields[name] = value
        }
        if let location {
            fields["Location"] = location.absoluteString
        }
        return HTTPURLResponse(url: response.url ?? WaybackSnapshot.archiveRoot,
                               statusCode: response.statusCode, httpVersion: "HTTP/1.1",
                               headerFields: fields) ?? response
    }
}
