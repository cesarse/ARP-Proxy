import Foundation
import SwiftSoup

/// Vintage browsers ignore <iframe> tags; leave a link to the framed page
/// instead of silently dropping the content.
nonisolated struct ReplaceIframesPass: HTMLPass {
    func run(on doc: Document) throws {
        for frame in try doc.select("iframe").array() {
            let src = try frame.attr("src")
            if src.hasPrefix("http") {
                let anchor = try Element(Tag.valueOf("a"), "")
                try anchor.attr("href", src)
                try anchor.appendText("[embedded: \(src)]")
                let paragraph = try Element(Tag.valueOf("p"), "")
                try paragraph.appendChild(anchor)
                try frame.replaceWith(paragraph)
            } else {
                try frame.remove()
            }
        }
    }
}
