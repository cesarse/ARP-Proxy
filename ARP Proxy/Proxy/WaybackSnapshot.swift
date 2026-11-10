import Foundation

/// A Wayback Machine snapshot address: an original URL as captured near a
/// 14-digit `YYYYMMDDhhmmss` timestamp. Builds the address to fetch, and
/// parses the archive's own redirects back into original URLs.
nonisolated struct WaybackSnapshot: Equatable, Sendable {
    let original: URL
    let timestamp: String

    static let archiveRoot = URL(string: "https://web.archive.org/")!

    init(original: URL, timestamp: String) {
        self.original = original
        self.timestamp = timestamp
    }

    /// Parses `https://web.archive.org/web/<timestamp><flag>/<original>`,
    /// absolute or relative to `base`. Returns nil for anything else,
    /// including timestamp-less addresses (the archive's lookup pages).
    init?(parsing location: String, relativeTo base: URL? = nil) {
        guard let url = URL(string: location, relativeTo: base)?.absoluteURL,
              Self.isArchive(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let path = components.percentEncodedPath
        guard path.hasPrefix("/web/") else { return nil }
        let rest = path.dropFirst("/web/".count)
        guard let slash = rest.firstIndex(of: "/"),
              let timestamp = Self.timestamp(inSegment: rest[..<slash])
        else { return nil }
        // The original URL's own query string arrives as the snapshot's.
        var raw = String(rest[rest.index(after: slash)...])
        if let query = components.percentEncodedQuery {
            raw += "?" + query
        }
        guard let original = Self.originalURL(from: raw) else { return nil }
        self.init(original: original, timestamp: timestamp)
    }

    /// The `id_` flag asks for the archived bytes exactly as captured: no
    /// toolbar and no link rewriting, so the page keeps its original
    /// addresses and every click comes back through the proxy.
    var url: URL? {
        URL(string: "https://web.archive.org/web/\(timestamp)id_/\(original.absoluteString)")
    }

    /// Noon of `date`'s day, in the given time zone. Always Gregorian, so a
    /// user on another calendar still asks the archive for the right year.
    static func timestamp(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld%02ld%02ld120000", day.year ?? 2001, day.month ?? 1, day.day ?? 1)
    }

    /// `20011208183522` → `2001-12-08`, for the request log.
    static func day(ofTimestamp timestamp: String) -> String {
        let digits = Array(timestamp)
        guard digits.count >= 8 else { return timestamp }
        return "\(String(digits[0..<4]))-\(String(digits[4..<6]))-\(String(digits[6..<8]))"
    }

    /// The archive's own hosts, which are browsed live even in Wayback mode
    /// — wrapping web.archive.org inside itself would make no sense.
    static func isArchive(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "archive.org" || host.hasSuffix(".archive.org")
    }

    /// `20011208183522id_` → `20011208183522`; nil if the segment is not a
    /// timestamp with an optional two-letter flag.
    private static func timestamp(inSegment segment: Substring) -> String? {
        let digits = segment.prefix { $0.isASCII && $0.isNumber }
        guard (1...14).contains(digits.count) else { return nil }
        let flag = segment.dropFirst(digits.count)
        let isFlag = flag.isEmpty
            || (flag.count == 3 && flag.hasSuffix("_")
                && flag.dropLast().allSatisfy { $0.isASCII && $0.isLetter })
        return isFlag ? String(digits) : nil
    }

    /// The archive writes originals loosely: sometimes without a scheme,
    /// sometimes with `http:/` collapsed from `http://`.
    private static func originalURL(from raw: String) -> URL? {
        var string = raw
        let lower = string.lowercased()
        for scheme in ["http:", "https:"]
        where lower.hasPrefix(scheme + "/") && !lower.hasPrefix(scheme + "//") {
            string.insert("/", at: string.index(string.startIndex, offsetBy: scheme.count))
        }
        if !string.lowercased().hasPrefix("http://") && !string.lowercased().hasPrefix("https://") {
            string = "http://" + string
        }
        guard let url = URL(string: string), url.host != nil else { return nil }
        return url
    }
}
