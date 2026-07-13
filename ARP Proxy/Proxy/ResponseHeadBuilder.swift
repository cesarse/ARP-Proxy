import Foundation

/// Builds the downgraded HTTP/1.0 response head sent to the vintage
/// browser: modern-only headers dropped, redirect URLs rewritten to http,
/// explicit Content-Length, Connection: close.
nonisolated enum ResponseHeadBuilder {
    private static let droppedHeaders: Set<String> = [
        "connection", "keep-alive", "proxy-authenticate", "proxy-connection",
        "transfer-encoding", "upgrade", "trailer",
        "content-encoding", "content-length",
        "strict-transport-security", "content-security-policy",
        "content-security-policy-report-only", "x-content-security-policy",
        "alt-svc", "x-frame-options", "permissions-policy", "report-to", "nel",
        "cross-origin-opener-policy", "cross-origin-embedder-policy",
        "cross-origin-resource-policy",
    ]

    private static let rewrittenURLHeaders: Set<String> = [
        "location", "refresh", "content-location",
    ]

    static func build(for response: HTTPURLResponse, bodyLength: Int,
                      contentTypeOverride: String?) -> String {
        var head = statusLine(for: response.statusCode)
        head += passedThroughHeaders(of: response,
                                     overridingContentType: contentTypeOverride != nil)
        if let contentTypeOverride {
            head += "Content-Type: \(contentTypeOverride)\r\n"
        }
        head += "Content-Length: \(bodyLength)\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"
        return head
    }

    private static func statusLine(for status: Int) -> String {
        "HTTP/1.0 \(status) \(HTTPReasonPhrase.phrase(for: status))\r\n"
    }

    private static func passedThroughHeaders(of response: HTTPURLResponse,
                                             overridingContentType: Bool) -> String {
        var lines = ""
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String, let value = value as? String else { continue }
            let lower = name.lowercased()
            guard !droppedHeaders.contains(lower) else { continue }
            if lower == "content-type", overridingContentType { continue }
            lines += "\(name): \(sanitized(downgraded(value, header: lower)))\r\n"
        }
        return lines
    }

    private static func downgraded(_ value: String, header: String) -> String {
        guard rewrittenURLHeaders.contains(header) else { return value }
        return value.replacingOccurrences(of: "https://", with: "http://")
    }

    /// Header values must never contain CR/LF (response splitting).
    private static func sanitized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
