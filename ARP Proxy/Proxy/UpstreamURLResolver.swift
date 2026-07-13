import Foundation

/// Turns the browser's request target into the URL to fetch.
nonisolated enum UpstreamURLResolver {
    /// Absolute-form proxy targets (`GET http://host/path`) are used as-is;
    /// origin-form targets (`GET /path` plus a Host header) are also accepted
    /// so the app can act as a plain gateway.
    static func url(for request: HTTPRequest) -> URL? {
        let target = request.target
        if target.lowercased().hasPrefix("http://") || target.lowercased().hasPrefix("https://") {
            return URL(string: target)
        }
        if target.hasPrefix("/"), let host = request.value(for: "Host") {
            return URL(string: "http://\(host)\(target)")
        }
        return nil
    }
}
