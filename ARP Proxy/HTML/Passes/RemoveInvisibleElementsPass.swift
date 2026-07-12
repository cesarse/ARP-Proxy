import Foundation
import SwiftSoup

/// Content hidden by attribute or inline style must be dropped before
/// styles are stripped, or dismissed banners and menus would suddenly
/// become visible text.
nonisolated struct RemoveInvisibleElementsPass: HTMLPass {
    func run(on doc: Document) throws {
        try doc.select("[hidden]").remove()
        for element in try doc.select("[style]").array() {
            let style = try element.attr("style").lowercased()
                .replacingOccurrences(of: " ", with: "")
            if style.contains("display:none") || style.contains("visibility:hidden") {
                try element.remove()
            }
        }
    }
}
