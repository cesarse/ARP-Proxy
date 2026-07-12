import Foundation
import SwiftSoup

/// Block-level HTML5 containers become <div> (an HTML 3.2 tag) so vintage
/// browsers keep the block layout instead of inlining everything.
nonisolated struct RenameSemanticTagsPass: HTMLPass {
    private static let renamedToDiv =
        "main, article, section, nav, aside, header, footer, figure, figcaption, hgroup, details, summary, search"

    func run(on doc: Document) throws {
        for element in try doc.select(Self.renamedToDiv).array() {
            _ = try element.tagName("div")
        }
    }
}
