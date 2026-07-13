import Foundation

/// Applies the configured downgrades to a response body: HTML
/// simplification, https→http rewriting in textual content, and image
/// transcoding.
nonisolated struct BodyTransformer: Sendable {
    private static let rewritableContentTypes: [String] = [
        "text/html", "application/xhtml+xml", "text/css",
        "text/javascript", "application/javascript", "application/x-javascript",
    ]

    private let settings: ProxySettings

    init(settings: ProxySettings) {
        self.settings = settings
    }

    func transform(_ body: Data, contentType: String) -> TransformedBody {
        if isRewritableText(contentType) {
            return transformText(body, contentType: contentType)
        }
        return transformImageIfEnabled(body, contentType: contentType)
    }

    private func isRewritableText(_ contentType: String) -> Bool {
        Self.rewritableContentTypes.contains { contentType.hasPrefix($0) }
    }

    private func transformText(_ body: Data, contentType: String) -> TransformedBody {
        if settings.simplifyHTML, contentType.hasPrefix("text/html"),
           let simplified = HTMLSimplifier.simplify(body, contentType: contentType,
                                                    settings: settings) {
            // The simplified output is pure ASCII, valid in any charset;
            // advertise one that every vintage browser knows.
            return TransformedBody(data: SchemeRewriter.rewrite(simplified),
                                   contentTypeOverride: "text/html; charset=iso-8859-1",
                                   note: "simplified")
        }
        return TransformedBody(data: SchemeRewriter.rewrite(body),
                               contentTypeOverride: nil, note: nil)
    }

    private func transformImageIfEnabled(_ body: Data, contentType: String) -> TransformedBody {
        guard settings.convertImages,
              let transcoded = ImageTranscoder.transcodeIfNeeded(
                  body, contentType: contentType,
                  jpegQuality: settings.jpegQuality,
                  maxPixelSize: settings.maxImageDimension)
        else {
            return TransformedBody(data: body, contentTypeOverride: nil, note: nil)
        }
        return TransformedBody(data: transcoded.data,
                               contentTypeOverride: transcoded.contentType,
                               note: transcoded.note)
    }
}
