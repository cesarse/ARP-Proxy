import Foundation

/// A self-rendering error response: minimal HTML 3.2, plain ASCII so any
/// vintage browser can show it.
nonisolated struct ErrorPage: Sendable {
    let status: Int
    let title: String
    let message: String

    /// The complete HTTP/1.0 response, head and body.
    func encodedResponse() -> Data {
        let body = Data(html.utf8)
        let head = "HTTP/1.0 \(status) \(HTTPReasonPhrase.phrase(for: status))\r\n"
            + "Content-Type: text/html\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var response = Data(head.utf8)
        response.append(body)
        return response
    }

    private var html: String {
        """
        <html><head><title>\(title)</title></head>\
        <body><h1>\(title)</h1><p>\(message)</p>\
        <hr><p><i>ARP Proxy</i></p></body></html>
        """
    }
}
