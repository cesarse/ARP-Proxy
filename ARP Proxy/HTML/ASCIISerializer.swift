import Foundation

/// Post-serialization passes that guarantee a pre-Unicode browser can
/// display the byte stream: decimal entities only, typographic characters
/// transliterated, and nothing above 0x7F left raw.
nonisolated enum ASCIISerializer {

    /// Typographic Unicode that pre-Unicode browsers can't show, mapped to
    /// ASCII stand-ins. Quotes map to entities so they stay safe inside
    /// attribute values.
    private static let substitutions: [(scalar: Unicode.Scalar, replacement: String)] = [
        ("\u{2018}", "&#39;"), ("\u{2019}", "&#39;"), ("\u{201A}", "&#39;"),
        ("\u{201C}", "&quot;"), ("\u{201D}", "&quot;"), ("\u{201E}", "&quot;"),
        ("\u{2013}", "-"), ("\u{2014}", "--"), ("\u{2026}", "..."),
        ("\u{2022}", "*"), ("\u{200B}", ""), ("\u{FEFF}", ""),
    ]

    private static let hexEntityPattern = try! NSRegularExpression(
        pattern: "&#[xX]([0-9a-fA-F]{1,6});")

    /// Very old browsers only understand decimal character references.
    static func decimalizeHexEntities(_ html: String) -> String {
        guard html.contains("&#x") || html.contains("&#X") else { return html }
        var result = ""
        var last = html.startIndex
        let matches = hexEntityPattern.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            guard let range = Range(match.range, in: html),
                  let hexRange = Range(match.range(at: 1), in: html),
                  let value = UInt32(html[hexRange], radix: 16)
            else { continue }
            result += html[last..<range.lowerBound]
            result += "&#\(value);"
            last = range.upperBound
        }
        result += html[last...]
        return result
    }

    static func transliterate(_ html: String) -> String {
        var result = html
        for (scalar, replacement) in substitutions {
            result = result.replacingOccurrences(of: String(scalar), with: replacement)
            result = result.replacingOccurrences(of: "&#\(scalar.value);", with: replacement)
        }
        return result
    }

    /// Safety net: whatever the serializer left as raw non-ASCII becomes a
    /// decimal entity, guaranteeing a byte stream every charset can carry.
    static func escapeNonASCII(_ html: String) -> String {
        guard html.contains(where: { !$0.isASCII }) else { return html }
        var result = ""
        result.reserveCapacity(html.count + 64)
        for scalar in html.unicodeScalars {
            if scalar.isASCII {
                result.unicodeScalars.append(scalar)
            } else {
                result += "&#\(scalar.value);"
            }
        }
        return result
    }
}
