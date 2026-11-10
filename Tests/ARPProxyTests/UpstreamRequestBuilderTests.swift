import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Upstream request builder")
struct UpstreamRequestBuilderTests {

    private let url = URL(string: "https://example.com/page.html")!

    @Test("The method and the resolved URL are carried over")
    func methodAndURL() {
        let upstream = UpstreamRequestBuilder.request(for: url, from: .fixture(method: "HEAD"))
        #expect(upstream.httpMethod == "HEAD")
        #expect(upstream.url == url)
    }

    @Test("Hop-by-hop and modern-protocol headers are never forwarded",
          arguments: [
              "Connection", "Proxy-Connection", "Proxy-Authorization", "Keep-Alive",
              "TE", "Trailer", "Transfer-Encoding", "Upgrade",
              "Accept-Encoding", "Host", "Content-Length", "Upgrade-Insecure-Requests",
          ])
    func dropsHeader(_ name: String) {
        let request = HTTPRequest.fixture(headers: [(name, "x"), (name.lowercased(), "y")])
        let upstream = UpstreamRequestBuilder.request(for: url, from: request)
        #expect(upstream.value(forHTTPHeaderField: name) == nil)
    }

    @Test("End-to-end headers are forwarded verbatim",
          arguments: [
              ("User-Agent", "Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)"),
              ("Accept", "*/*"),
              ("Accept-Language", "pt-br"),
              ("Cookie", "session=abc"),
              ("Referer", "http://example.com/"),
              ("If-Modified-Since", "Sat, 08 Dec 2001 23:40:11 GMT"),
          ])
    func forwardsHeader(_ name: String, _ value: String) {
        let request = HTTPRequest.fixture(headers: [(name, value)])
        let upstream = UpstreamRequestBuilder.request(for: url, from: request)
        #expect(upstream.value(forHTTPHeaderField: name) == value)
    }

    @Test("A request body is attached")
    func attachesBody() {
        let body = Data("q=retro".utf8)
        let upstream = UpstreamRequestBuilder.request(
            for: url, from: .fixture(method: "POST", body: body))
        #expect(upstream.httpBody == body)
    }

    @Test("An empty body is not attached")
    func omitsEmptyBody() {
        let upstream = UpstreamRequestBuilder.request(for: url, from: .fixture())
        #expect(upstream.httpBody == nil)
    }
}
