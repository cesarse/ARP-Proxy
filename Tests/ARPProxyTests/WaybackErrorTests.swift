import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Wayback error")
struct WaybackErrorTests {

    private let original = URL(string: "http://www.cnn.com/")!

    @Test("Each failure maps to a status an HTTP/1.0 browser understands",
          arguments: [
              (WaybackError.notArchived, 404), (.rateLimited, 503),
              (.unavailable(status: 500), 502), (.tooManyRedirects, 502),
          ])
    func status(_ error: WaybackError, _ status: Int) {
        #expect(error.errorPage(for: original, near: .now).status == status)
    }

    @Test("The not-archived page names the address and the date, in English")
    func notArchivedMessage() {
        let page = WaybackError.notArchived.errorPage(for: original,
                                                      near: ProxySettings.defaultWaybackDate)
        #expect(page.message.contains("http://www.cnn.com/"))
        #expect(page.message.contains("December 8, 2001"))
    }
}
