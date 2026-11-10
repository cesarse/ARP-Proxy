import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Wayback snapshot")
struct WaybackSnapshotTests {

    private func parse(_ location: String, relativeTo base: String? = nil) -> WaybackSnapshot? {
        WaybackSnapshot(parsing: location, relativeTo: base.flatMap(URL.init(string:)))
    }

    // MARK: Building

    @Test("The snapshot address asks for the raw capture with the id_ flag")
    func buildsRawCaptureURL() {
        let snapshot = WaybackSnapshot(original: URL(string: "http://www.cnn.com/")!,
                                       timestamp: "20011208120000")
        #expect(snapshot.url?.absoluteString
                == "https://web.archive.org/web/20011208120000id_/http://www.cnn.com/")
    }

    @Test("The original's query string stays part of the snapshot address")
    func buildKeepsQuery() {
        let snapshot = WaybackSnapshot(original: URL(string: "http://example.com/s?q=mac&p=2")!,
                                       timestamp: "20011208120000")
        #expect(snapshot.url?.absoluteString
                == "https://web.archive.org/web/20011208120000id_/http://example.com/s?q=mac&p=2")
    }

    // MARK: Parsing

    @Test("An absolute snapshot address yields its timestamp and original")
    func parsesAbsolute() {
        let snapshot = parse("https://web.archive.org/web/20011208183522id_/http://cnn.com/")
        #expect(snapshot?.timestamp == "20011208183522")
        #expect(snapshot?.original.absoluteString == "http://cnn.com/")
    }

    @Test("A relative snapshot address is resolved against the archive")
    func parsesRelative() {
        let snapshot = parse("/web/20011208183522id_/http://cnn.com/",
                             relativeTo: "https://web.archive.org/web/20011208120000id_/http://www.cnn.com/")
        #expect(snapshot?.original.absoluteString == "http://cnn.com/")
    }

    @Test("Parsing round-trips what building produced")
    func roundTrips() {
        let built = WaybackSnapshot(original: URL(string: "https://github.com/a/b?x=1&y=2")!,
                                    timestamp: "20200601115844")
        #expect(parse(built.url!.absoluteString) == built)
    }

    @Test("The original's query string is recovered from the snapshot's")
    func parsesQuery() {
        let snapshot = parse("https://web.archive.org/web/2001id_/http://example.com/cgi?a=1&b=2")
        #expect(snapshot?.original.absoluteString == "http://example.com/cgi?a=1&b=2")
    }

    @Test("Timestamps of any precision, with or without a flag, are accepted",
          arguments: [
              ("2001", "2001"), ("20011208", "20011208"), ("20011208183522", "20011208183522"),
              ("20011208183522im_", "20011208183522"), ("20011208183522js_", "20011208183522"),
          ])
    func parsesTimestampSegment(_ segment: String, _ timestamp: String) {
        #expect(parse("https://web.archive.org/web/\(segment)/http://example.com/")?.timestamp
                == timestamp)
    }

    @Test("Explicit default ports in the original survive parsing")
    func keepsExplicitPort() {
        let snapshot = parse("https://web.archive.org/web/20011208011212id_/"
                             + "http://www.amazon.com:80/exec/obidos/subst/home/redirect.html")
        #expect(snapshot?.original.port == 80)
        #expect(snapshot?.original.path == "/exec/obidos/subst/home/redirect.html")
    }

    @Test("A scheme collapsed to http:/ is repaired")
    func repairsCollapsedScheme() {
        #expect(parse("https://web.archive.org/web/2001id_/http:/example.com/a")?
                    .original.absoluteString == "http://example.com/a")
    }

    @Test("An original without a scheme is taken as http")
    func addsMissingScheme() {
        #expect(parse("https://web.archive.org/web/2001id_/example.com/a")?
                    .original.absoluteString == "http://example.com/a")
    }

    @Test("Addresses that are not snapshots are not parsed",
          arguments: [
              "https://example.com/web/2001id_/http://example.com/",
              "https://web.archive.org/details/texts",
              "https://web.archive.org/web/http://example.com/",
              "https://web.archive.org/web/*/example.com",
              "https://web.archive.org/web/2001xyz_/http://example.com/",
              "https://web.archive.org/web/123456789012345/http://example.com/",
          ])
    func rejectsNonSnapshots(_ location: String) {
        #expect(parse(location) == nil)
    }

    // MARK: Timestamps and hosts

    @Test("A date asks for noon of its day, in the given time zone")
    func timestampIsNoonOfTheDay() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        // 00:30 on the 8th in Tokyo is still the 7th in UTC.
        let date = calendar.date(from: DateComponents(year: 2001, month: 12, day: 8, hour: 0, minute: 30))!
        #expect(WaybackSnapshot.timestamp(for: date, timeZone: tokyo) == "20011208120000")
        #expect(WaybackSnapshot.timestamp(for: date, timeZone: .gmt) == "20011207120000")
    }

    @Test("A capture timestamp is shown as its day")
    func dayOfTimestamp() {
        #expect(WaybackSnapshot.day(ofTimestamp: "20011208183522") == "2001-12-08")
        #expect(WaybackSnapshot.day(ofTimestamp: "2001") == "2001")
    }

    @Test("The archive's own hosts are recognized",
          arguments: [
              ("https://web.archive.org/web/", true), ("http://archive.org/", true),
              ("http://WAYBACK.archive.org/", true), ("http://notarchive.org/", false),
              ("http://archive.org.example.com/", false),
          ])
    func recognizesArchiveHosts(_ url: String, _ isArchive: Bool) {
        #expect(WaybackSnapshot.isArchive(URL(string: url)!) == isArchive)
    }
}
