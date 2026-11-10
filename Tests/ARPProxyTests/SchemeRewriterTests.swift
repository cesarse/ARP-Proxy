import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Scheme rewriter")
struct SchemeRewriterTests {

    private func rewrite(_ string: String) -> String {
        String(decoding: SchemeRewriter.rewrite(Data(string.utf8)), as: UTF8.self)
    }

    @Test("Every https:// becomes http://")
    func rewritesAllOccurrences() {
        let html = #"<a href="https://a.example/">a</a><img src="https://b.example/x.png">"#
        #expect(rewrite(html) == #"<a href="http://a.example/">a</a><img src="http://b.example/x.png">"#)
    }

    @Test("Back-to-back occurrences are all rewritten")
    func rewritesAdjacentOccurrences() {
        #expect(rewrite("https://https://") == "http://http://")
    }

    @Test("Text without https:// is returned unchanged")
    func leavesOtherTextAlone() {
        let css = "body { background: url(http://example.com/bg.gif) }"
        #expect(rewrite(css) == css)
    }

    @Test("An empty body stays empty")
    func emptyBody() {
        #expect(SchemeRewriter.rewrite(Data()).isEmpty)
    }

    @Test("Bytes around a match are preserved, even when they are not UTF-8")
    func preservesNonUTF8Bytes() {
        let latin1 = Data([0xE9]) + Data("https://x/".utf8) + Data([0xFF, 0x00])
        let expected = Data([0xE9]) + Data("http://x/".utf8) + Data([0xFF, 0x00])
        #expect(SchemeRewriter.rewrite(latin1) == expected)
    }
}
