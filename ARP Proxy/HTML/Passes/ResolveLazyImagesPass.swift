import Foundation
import SwiftSoup

/// Promotes lazy-loading attributes into a real src, since no vintage
/// browser will ever run the JavaScript that was meant to do it. Also
/// (optionally) strips width/height: modern sites size images with CSS,
/// so the attributes often describe a different crop than the served file
/// and would stretch the image in a CSS-less browser.
nonisolated struct ResolveLazyImagesPass: HTMLPass {
    let stripDimensions: Bool

    func run(on doc: Document) throws {
        for img in try doc.select("img").array() {
            try process(img)
        }
    }

    private func process(_ img: Element) throws {
        if stripDimensions {
            try img.removeAttr("width")
            try img.removeAttr("height")
        }
        let src = try img.attr("src")
        guard src.isEmpty || src.hasPrefix("data:") else { return }
        let replacement = try lazyReplacement(for: img)
        if !replacement.isEmpty, !replacement.hasPrefix("data:") {
            try img.attr("src", replacement)
        } else if !src.isEmpty {
            // data: URI with no usable alternative — unrenderable.
            try img.remove()
        }
    }

    private func lazyReplacement(for img: Element) throws -> String {
        for key in ["data-src", "data-lazy-src", "data-original"] {
            let candidate = try img.attr(key)
            if !candidate.isEmpty { return candidate }
        }
        var srcset = try img.attr("srcset")
        if srcset.isEmpty { srcset = try img.attr("data-srcset") }
        return firstSrcsetURL(srcset)
    }

    private func firstSrcsetURL(_ srcset: String) -> String {
        guard let candidate = srcset.split(separator: ",").first else { return "" }
        return candidate.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? ""
    }
}
