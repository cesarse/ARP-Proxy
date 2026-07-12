import Foundation
import SwiftSoup

/// Strips attributes that only mean something to CSS, JS or modern
/// protocols. Runs late, after the passes that still need to read them.
nonisolated struct PruneAttributesPass: HTMLPass {
    private static let droppedAttributes: Set<String> = [
        "class", "style", "role", "slot", "part", "is", "nonce",
        "async", "defer", "integrity", "crossorigin", "referrerpolicy",
        "ping", "tabindex", "hidden", "loading", "decoding", "fetchpriority",
        "srcset", "sizes", "autocomplete", "autofocus", "autocapitalize",
        "contenteditable", "draggable", "spellcheck", "translate",
        "itemprop", "itemscope", "itemtype", "itemid",
        "enterkeyhint", "inputmode", "popover", "popovertarget", "inert",
    ]

    func run(on doc: Document) throws {
        for element in try doc.getAllElements().array() {
            try prune(element)
        }
    }

    private func prune(_ element: Element) throws {
        guard let attributes = element.getAttributes() else { return }
        let doomed = attributes.asList()
            .map { $0.getKey() }
            .filter { isDropped($0.lowercased()) }
        for key in doomed {
            try element.removeAttr(key)
        }
    }

    private func isDropped(_ key: String) -> Bool {
        Self.droppedAttributes.contains(key)
            || key.hasPrefix("data-") || key.hasPrefix("aria-") || key.hasPrefix("on")
    }
}
