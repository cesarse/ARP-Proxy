import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("HTTPS upgrader")
struct HTTPSUpgraderTests {

    private func candidates(_ string: String) -> [String] {
        HTTPSUpgrader.candidates(for: URL(string: string)!).map(\.absoluteString)
    }

    @Test("An http:// URL is tried over HTTPS first, then as requested")
    func upgradesHTTP() {
        #expect(candidates("http://example.com/a/b.html?q=1")
                == ["https://example.com/a/b.html?q=1", "http://example.com/a/b.html?q=1"])
    }

    @Test("An explicit port 80 is dropped from the HTTPS candidate")
    func dropsDefaultPort() {
        #expect(candidates("http://example.com:80/")
                == ["https://example.com/", "http://example.com:80/"])
    }

    @Test("A non-default port is never upgraded: HTTPS would not listen there")
    func keepsCustomPort() {
        #expect(candidates("http://example.com:8080/") == ["http://example.com:8080/"])
    }

    @Test("An https:// URL is left alone")
    func leavesHTTPSAlone() {
        #expect(candidates("https://example.com/") == ["https://example.com/"])
    }
}
