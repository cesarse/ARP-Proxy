import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Upstream URL resolver")
struct UpstreamURLResolverTests {

    @Test("An absolute http:// proxy target is used as-is")
    func absoluteHTTPTarget() {
        let url = UpstreamURLResolver.url(for: .fixture(target: "http://example.com/a/b.html?q=1"))
        #expect(url?.absoluteString == "http://example.com/a/b.html?q=1")
    }

    @Test("An absolute https:// proxy target is used as-is")
    func absoluteHTTPSTarget() {
        let url = UpstreamURLResolver.url(for: .fixture(target: "https://example.com/"))
        #expect(url?.absoluteString == "https://example.com/")
    }

    @Test("The scheme of an absolute target is matched case-insensitively")
    func uppercaseScheme() {
        let url = UpstreamURLResolver.url(for: .fixture(target: "HTTP://example.com/"))
        #expect(url?.host == "example.com")
    }

    @Test("An origin-form target is resolved against the Host header")
    func originFormTarget() {
        let request = HTTPRequest.fixture(target: "/path/page.html?x=y",
                                          headers: [("Host", "example.com:8000")])
        let url = UpstreamURLResolver.url(for: request)
        #expect(url?.absoluteString == "http://example.com:8000/path/page.html?x=y")
    }

    @Test("The Host header is looked up case-insensitively")
    func lowercaseHostHeader() {
        let request = HTTPRequest.fixture(target: "/", headers: [("host", "example.com")])
        #expect(UpstreamURLResolver.url(for: request)?.absoluteString == "http://example.com/")
    }

    @Test("An origin-form target without a Host header is rejected")
    func originFormWithoutHost() {
        #expect(UpstreamURLResolver.url(for: .fixture(target: "/page.html")) == nil)
    }

    @Test("A target that is neither absolute nor origin-form is rejected")
    func unsupportedTargetForm() {
        let request = HTTPRequest.fixture(target: "example.com/page.html",
                                          headers: [("Host", "example.com")])
        #expect(UpstreamURLResolver.url(for: request) == nil)
    }
}
