import Foundation
import SwiftSoup

/// HTML 3.2 predates a handful of inline tags from HTML 4; unwrap them
/// (their content flows on) and turn <q> into literal quotation marks.
nonisolated struct DowngradeHTML4InlineTagsPass: HTMLPass {
    func run(on doc: Document) throws {
        for quote in try doc.select("q").array() {
            try quote.prependText("\"")
            try quote.appendText("\"")
        }
        try doc.select("q, abbr, acronym, ins, del, bdo, span").unwrap()
    }
}
