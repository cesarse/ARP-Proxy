import Foundation
import SwiftSoup

/// Unwraps every element the target dialect has no name for, letting the
/// children flow on so the text survives.
///
/// Three kinds of tag end up here. HTML5 additions the earlier passes do not
/// name (`<bdi>`, `<wbr>`); Web Components, which are unbounded — any
/// hyphenated tag a site invents (`<react-partial>`, `<include-fragment>`);
/// and, for HTML 3.2, the table sections `<tbody>`/`<thead>`/`<tfoot>` that
/// *our own parser inserts* — SwiftSoup does HTML5 tree construction, so a
/// table with no `<tbody>` in the source comes back with one.
///
/// A vintage browser would ignore an unknown tag and render the content
/// anyway, so this is about honesty rather than rescue: without it the
/// DOCTYPE we emit is a claim the document does not honour.
nonisolated struct UnwrapUnknownElementsPass: HTMLPass {
    private let vocabulary: Set<String>

    init(vocabulary: Set<String>) {
        self.vocabulary = vocabulary
    }

    func run(on doc: Document) throws {
        for element in try doc.getAllElements().array() {
            let tag = element.tagName().lowercased()
            // SwiftSoup names the document node "#root"; it is not markup.
            guard !tag.hasPrefix("#"), !vocabulary.contains(tag) else { continue }
            try element.unwrap()
        }
    }
}
