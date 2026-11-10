import Foundation
import Testing
@testable import ARPProxyHTML

/// The responses here mirror what web.archive.org actually sent when the
/// feature was built (CNN, Amazon, Apple and GitHub captures, and a host
/// that was never archived).
@Suite("Wayback answer")
struct WaybackAnswerTests {

    private let requested = URL(string: "http://www.cnn.com/")!
    private let fetched = "https://web.archive.org/web/20011208120000id_/http://www.cnn.com/"

    private func response(_ status: Int, at url: String? = nil,
                          _ headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: url ?? fetched)!, statusCode: status,
                        httpVersion: "HTTP/1.1", headerFields: headers)!
    }

    private func followed(_ answer: WaybackAnswer) -> String? {
        if case .follow(let url) = answer { return url.absoluteString }
        return nil
    }

    private func delivered(_ answer: WaybackAnswer) -> HTTPURLResponse? {
        if case .deliver(let response) = answer { return response }
        return nil
    }

    private func failure(_ answer: WaybackAnswer) -> WaybackError? {
        if case .fail(let error) = answer { return error }
        return nil
    }

    // MARK: Redirects the proxy follows itself

    @Test("The archive's nearest-capture redirect is followed, not shown")
    func followsTimestampRedirect() {
        let answer = WaybackAnswer.interpret(response(302, [
            "Location": "https://web.archive.org/web/20011208183522id_/http://cnn.com/",
            "X-Archive-Redirect-Reason": "found capture at 20011208183522",
        ]), requested: requested)
        #expect(followed(answer) == "https://web.archive.org/web/20011208183522id_/http://cnn.com/")
    }

    @Test("A relative Location is resolved against the snapshot fetched")
    func followsRelativeRedirect() {
        let answer = WaybackAnswer.interpret(response(302, [
            "Location": "/web/20011208234115id_/http://www.cnn.com/",
        ]), requested: requested)
        #expect(followed(answer) == "https://web.archive.org/web/20011208234115id_/http://www.cnn.com/")
    }

    @Test("A captured http → https upgrade is followed: the browser would loop on it")
    func followsSchemeOnlyRedirect() {
        let answer = WaybackAnswer.interpret(response(302,
            at: "https://web.archive.org/web/20200601120000id_/http://github.com/", [
                "Location": "https://web.archive.org/web/20200601115844id_/https://github.com/",
                "Memento-Datetime": "Mon, 01 Jun 2020 11:58:44 GMT",
            ]), requested: URL(string: "http://github.com/")!)
        #expect(followed(answer) == "https://web.archive.org/web/20200601115844id_/https://github.com/")
    }

    @Test("Followed snapshots always ask for the raw capture")
    func followForcesRawFlag() {
        let answer = WaybackAnswer.interpret(response(302, [
            "Location": "https://web.archive.org/web/20011208183522/http://www.cnn.com/",
        ]), requested: requested)
        #expect(followed(answer) == "https://web.archive.org/web/20011208183522id_/http://www.cnn.com/")
    }

    // MARK: Redirects the browser must see

    @Test("A redirect the site made back then reaches the browser, as the site's address")
    func relaysArchivedRedirect() throws {
        let answer = WaybackAnswer.interpret(response(302,
            at: "https://web.archive.org/web/20011208011212id_/http://www.amazon.com/", [
                "Location": "https://web.archive.org/web/20011208011212id_/"
                    + "http://www.amazon.com:80/exec/obidos/subst/home/redirect.html",
                "Memento-Datetime": "Sat, 08 Dec 2001 01:12:12 GMT",
            ]), requested: URL(string: "http://www.amazon.com/")!)
        let relayed = try #require(delivered(answer))
        #expect(relayed.statusCode == 302)
        #expect(relayed.value(forHTTPHeaderField: "Location")
                == "http://www.amazon.com/exec/obidos/subst/home/redirect.html")
        #expect(relayed.value(forHTTPHeaderField: "Memento-Datetime") == nil)
    }

    @Test("A new trailing slash reaches the browser, so relative links resolve")
    func relaysTrailingSlash() throws {
        let answer = WaybackAnswer.interpret(response(302,
            at: "https://web.archive.org/web/20050601120000id_/http://www.apple.com/macosx", [
                "Location": "https://web.archive.org/web/20050601075017id_/http://www.apple.com/macosx/",
            ]), requested: URL(string: "http://www.apple.com/macosx")!)
        #expect(try #require(delivered(answer)).value(forHTTPHeaderField: "Location")
                == "http://www.apple.com/macosx/")
    }

    @Test("A relayed redirect to an https site is downgraded to http")
    func relaysAsHTTP() throws {
        let answer = WaybackAnswer.interpret(response(301, [
            "Location": "https://web.archive.org/web/2015id_/https://edition.cnn.com:443/",
            "Memento-Datetime": "Thu, 01 Jan 2015 00:00:00 GMT",
        ]), requested: requested)
        #expect(try #require(delivered(answer)).value(forHTTPHeaderField: "Location")
                == "http://edition.cnn.com/")
    }

    @Test("A redirect off the archive is passed along unchanged")
    func passesForeignRedirect() throws {
        let answer = WaybackAnswer.interpret(response(302, [
            "Location": "https://example.com/elsewhere",
        ]), requested: requested)
        #expect(try #require(delivered(answer)).value(forHTTPHeaderField: "Location")
                == "https://example.com/elsewhere")
    }

    // MARK: Captures

    @Test("A capture is delivered without the archive's own headers")
    func deliversCleanCapture() throws {
        let answer = WaybackAnswer.interpret(response(200, [
            "Content-Type": "text/html",
            "Cache-Control": "max-age=1800",
            "Memento-Datetime": "Sat, 08 Dec 2001 23:41:15 GMT",
            "Link": "<http://www.cnn.com:80/?>; rel=\"original\"",
            "X-Archive-Src": "INA-HISTORICAL-EMBEDS-2001.arc.gz",
            "X-Archive-Orig-Server": "Netscape-Enterprise/4.1",
            "X-App-Server": "wwwb-app221",
            "Server-Timing": "captures_list;dur=0.37",
            "Set-Cookie": "wb-p-SERVER=wwwb-app221; path=/",
            "Referrer-Policy": "no-referrer-when-downgrade",
        ]), requested: requested)
        let capture = try #require(delivered(answer))
        #expect(capture.statusCode == 200)
        let names = Set(capture.allHeaderFields.keys.compactMap { ($0 as? String)?.lowercased() })
        #expect(names == ["content-type", "cache-control"])
    }

    @Test("A captured 404 is the site's own page and is delivered")
    func deliversArchived404() throws {
        let answer = WaybackAnswer.interpret(response(404, [
            "Memento-Datetime": "Sat, 08 Dec 2001 23:41:15 GMT",
        ]), requested: requested)
        #expect(try #require(delivered(answer)).statusCode == 404)
    }

    // MARK: Failures

    @Test("A 404 that is not a capture means the page was never archived")
    func notArchived() {
        #expect(failure(WaybackAnswer.interpret(response(404), requested: requested)) == .notArchived)
        #expect(failure(WaybackAnswer.interpret(response(403), requested: requested)) == .notArchived)
    }

    @Test("Throttling is reported as such")
    func rateLimited() {
        #expect(failure(WaybackAnswer.interpret(response(429), requested: requested)) == .rateLimited)
    }

    @Test("A server error that is not a capture is the archive's own")
    func archiveFailure() {
        #expect(failure(WaybackAnswer.interpret(response(503), requested: requested))
                == .unavailable(status: 503))
    }
}
