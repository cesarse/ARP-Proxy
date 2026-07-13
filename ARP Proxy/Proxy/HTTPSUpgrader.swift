import Foundation

/// The "remove the S" trick in reverse: the browser asks for http://, we
/// try https:// first and fall back to the original URL.
nonisolated enum HTTPSUpgrader {
    static func candidates(for url: URL) -> [URL] {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.port == nil || components.port == 80
        else { return [url] }
        components.scheme = "https"
        components.port = nil
        guard let upgraded = components.url else { return [url] }
        return [upgraded, url]
    }
}
