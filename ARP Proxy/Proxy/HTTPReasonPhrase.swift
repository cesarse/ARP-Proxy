import Foundation

/// Reason phrases for the HTTP/1.0 status line.
nonisolated enum HTTPReasonPhrase {
    private static let phrases: [Int: String] = [
        200: "OK", 201: "Created", 204: "No Content", 206: "Partial Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 410: "Gone", 429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable", 504: "Gateway Timeout",
    ]

    static func phrase(for status: Int) -> String {
        phrases[status] ?? "OK"
    }
}
