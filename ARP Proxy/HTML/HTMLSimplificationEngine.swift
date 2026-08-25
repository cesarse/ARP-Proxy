import Foundation
import SwiftSoup

/// Runs the whole simplification: decode, parse, apply the pass pipeline
/// for the chosen dialect, and serialize to vintage-safe ASCII.
nonisolated struct HTMLSimplificationEngine: Sendable {
    /// Pages larger than this are passed through unsimplified.
    private static let maxInputBytes = 8 * 1024 * 1024

    private let dialect: any HTMLSimplifying
    private let settings: ProxySettings

    init(dialect: any HTMLSimplifying, settings: ProxySettings) {
        self.dialect = dialect
        self.settings = settings
    }

    /// Returns a simplified ASCII rendition of the page, or nil when the
    /// body should be passed through untouched (too big, undecodable, or
    /// SwiftSoup failed).
    func simplify(_ data: Data, contentType: String) -> Data? {
        guard !data.isEmpty, data.count <= Self.maxInputBytes,
              let html = HTMLInputDecoder.decode(data, contentType: contentType)
        else { return nil }
        do {
            let doc = try SwiftSoup.parse(html)
            try makePipeline().run(on: doc)
            return try serialize(doc)
        } catch {
            return nil
        }
    }

    /// Order matters: hidden-element removal reads style attributes and
    /// lazy-image resolution reads data-*, so both run before attribute
    /// pruning wipes those attributes out; <noscript> is unwrapped before
    /// the tag sweep so anything it spills out gets cleaned too.
    ///
    /// The unknown-element sweep runs last of the structural passes, and
    /// after the dialect's own: it would happily unwrap a <q> that
    /// `DowngradeHTML4InlineTagsPass` still needs to turn into quote marks,
    /// and it must see the <div>s that `RenameSemanticTagsPass` produces
    /// rather than the HTML5 containers they came from.
    private func makePipeline() -> HTMLPassPipeline {
        HTMLPassPipeline([
            RemoveInvisibleElementsPass(),
            ResolveLazyImagesPass(stripDimensions: settings.stripImageDimensions),
            ReplaceIframesPass(),
            ConvertButtonsPass(),
            NormalizeInputsPass(),
            UnwrapNoscriptPass(),
            FlattenPicturePass(),
            RemoveModernTagsPass(),
            RenameSemanticTagsPass(),
        ] + dialect.versionPasses + [
            UnwrapUnknownElementsPass(vocabulary: dialect.vocabulary),
            PruneAttributesPass(),
            RemoveCommentsPass(),
            ReplaceDoctypePass(doctype: dialect.doctype),
        ])
    }

    private func serialize(_ doc: Document) throws -> Data {
        let outputSettings = OutputSettings()
        _ = outputSettings.charset(String.Encoding.ascii)
        _ = outputSettings.escapeMode(Entities.EscapeMode.base)
        _ = outputSettings.prettyPrint(pretty: false)
        doc.outputSettings(outputSettings)

        var output = try doc.outerHtml()
        output = ASCIISerializer.decimalizeHexEntities(output)  // Netscape 3 can't do &#x…;
        output = ASCIISerializer.transliterate(output)
        output = ASCIISerializer.escapeNonASCII(output)
        return Data(output.utf8)
    }
}
