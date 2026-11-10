import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Wayback resource key")
struct WaybackResourceKeyTests {

    private func key(_ string: String) -> WaybackResourceKey {
        WaybackResourceKey(URL(string: string)!)
    }

    @Test("Differences the archive's index ignores make the same resource",
          arguments: [
              ("http://www.cnn.com/", "http://cnn.com/"),
              ("http://github.com/", "https://github.com/"),
              ("http://www.amazon.com:80/a.html", "http://www.amazon.com/a.html"),
              ("https://example.com:443/", "http://example.com/"),
              ("http://EXAMPLE.com/Index.HTML", "http://example.com/index.html"),
              ("http://www2.example.com/", "http://example.com/"),
              ("http://example.com/s?b=2&a=1", "http://example.com/s?a=1&b=2"),
              ("http://example.com", "http://example.com/"),
          ])
    func sameResource(_ a: String, _ b: String) {
        #expect(key(a) == key(b))
    }

    @Test("Anything else is a different resource",
          arguments: [
              ("http://www.apple.com/macosx", "http://www.apple.com/macosx/"),
              ("http://example.com/a", "http://example.com/b"),
              ("http://example.com/", "http://example.org/"),
              ("http://example.com/", "http://example.com:8080/"),
              ("http://example.com/s?a=1", "http://example.com/s?a=2"),
              ("http://news.example.com/", "http://example.com/"),
          ])
    func differentResource(_ a: String, _ b: String) {
        #expect(key(a) != key(b))
    }
}
