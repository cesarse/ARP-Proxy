import Foundation
import SwiftSoup

/// Swaps whatever DOCTYPE the page had for the target dialect's own.
nonisolated struct ReplaceDoctypePass: HTMLPass {
    let doctype: DoctypeDeclaration

    func run(on doc: Document) throws {
        for existing in NodeCollector.nodes(ofType: DocumentType.self, in: doc) {
            try existing.remove()
        }
        try doc.prependChild(doctype.makeNode())
    }
}
