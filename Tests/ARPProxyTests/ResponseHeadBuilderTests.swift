import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Response head builder")
struct ResponseHeadBuilderTests {

    /// A response head split into its status line and header lines. Header
    /// order follows a dictionary, so tests look headers up by name.
    private struct ParsedHead {
        let statusLine: String
        let headers: [(name: String, value: String)]

        func values(_ name: String) -> [String] {
            headers.filter { $0.name.lowercased() == name.lowercased() }.map(\.value)
        }

        func value(_ name: String) -> String? {
            values(name).first
        }
    }

    private func build(status: Int = 200, headers: [String: String] = [:],
                       bodyLength: Int = 0, contentTypeOverride: String? = nil) -> String {
        let response = HTTPURLResponse(url: URL(string: "https://example.com/")!,
                                       statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: headers)!
        return ResponseHeadBuilder.build(for: response, bodyLength: bodyLength,
                                         contentTypeOverride: contentTypeOverride)
    }

    private func parse(_ head: String) -> ParsedHead {
        var lines = head.components(separatedBy: "\r\n")
        let statusLine = lines.removeFirst()
        let headers = lines.prefix { !$0.isEmpty }.map { line -> (String, String) in
            let colon = line.firstIndex(of: ":")!
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (String(line[..<colon]), value)
        }
        return ParsedHead(statusLine: statusLine, headers: headers)
    }

    @Test("The status line is downgraded to HTTP/1.0 with a reason phrase")
    func statusLine() {
        #expect(parse(build(status: 404)).statusLine == "HTTP/1.0 404 Not Found")
        #expect(parse(build(status: 302)).statusLine == "HTTP/1.0 302 Found")
    }

    @Test("The head ends with an empty line")
    func terminatedByBlankLine() {
        #expect(build().hasSuffix("\r\n\r\n"))
    }

    @Test("Content-Length is the transformed body's, and the connection closes")
    func explicitLengthAndClose() {
        let head = parse(build(headers: ["Content-Length": "999", "Connection": "keep-alive"],
                               bodyLength: 42))
        #expect(head.values("Content-Length") == ["42"])
        #expect(head.values("Connection") == ["close"])
    }

    @Test("Modern-only and hop-by-hop response headers are dropped",
          arguments: [
              "Strict-Transport-Security", "Content-Security-Policy",
              "Content-Security-Policy-Report-Only", "X-Content-Security-Policy",
              "Alt-Svc", "X-Frame-Options", "Permissions-Policy", "Report-To", "NEL",
              "Cross-Origin-Opener-Policy", "Cross-Origin-Embedder-Policy",
              "Cross-Origin-Resource-Policy", "Content-Encoding", "Transfer-Encoding",
              "Keep-Alive", "Proxy-Authenticate", "Proxy-Connection", "Upgrade", "Trailer",
          ])
    func dropsHeader(_ name: String) {
        #expect(parse(build(headers: [name: "x"])).value(name) == nil)
    }

    @Test("Other response headers pass through unchanged")
    func passesThroughHeaders() {
        let head = parse(build(headers: [
            "Server": "Netscape-Enterprise/4.1",
            "Last-Modified": "Sat, 08 Dec 2001 23:40:11 GMT",
            "Set-Cookie": "session=abc; path=/",
            "Cache-Control": "max-age=60",
        ]))
        #expect(head.value("Server") == "Netscape-Enterprise/4.1")
        #expect(head.value("Last-Modified") == "Sat, 08 Dec 2001 23:40:11 GMT")
        #expect(head.value("Set-Cookie") == "session=abc; path=/")
        #expect(head.value("Cache-Control") == "max-age=60")
    }

    @Test("Redirect URLs are rewritten from https:// to http://",
          arguments: ["Location", "Content-Location", "Refresh"])
    func rewritesRedirectHeader(_ name: String) {
        let head = parse(build(status: 301, headers: [name: "https://example.com/next"]))
        #expect(head.value(name) == "http://example.com/next")
    }

    @Test("URLs in other headers are left alone")
    func leavesOtherURLsAlone() {
        let head = parse(build(headers: ["Link": "<https://example.com/>; rel=\"canonical\""]))
        #expect(head.value("Link") == "<https://example.com/>; rel=\"canonical\"")
    }

    @Test("A Content-Type override replaces the upstream Content-Type")
    func overridesContentType() {
        let head = parse(build(headers: ["Content-Type": "image/webp"],
                               contentTypeOverride: "image/jpeg"))
        #expect(head.values("Content-Type") == ["image/jpeg"])
    }

    @Test("Without an override the upstream Content-Type is kept")
    func keepsContentType() {
        let head = parse(build(headers: ["Content-Type": "text/html; charset=utf-8"]))
        #expect(head.values("Content-Type") == ["text/html; charset=utf-8"])
    }

    /// Foundation already discards a field containing CR or LF when the
    /// HTTPURLResponse is built, so the builder's own sanitizer is a second
    /// line of defense. The property that matters is end to end: no header
    /// line can be smuggled into the head.
    @Test("CR and LF in header values cannot split the response")
    func cannotSplitResponse() {
        let head = parse(build(headers: ["X-Note": "a\r\nInjected: yes"]))
        #expect(head.statusLine == "HTTP/1.0 200 OK")
        #expect(head.value("Injected") == nil)
    }
}
