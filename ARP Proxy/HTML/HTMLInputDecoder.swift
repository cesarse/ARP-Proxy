import Foundation

/// Decodes an HTML body into a String, honoring the charset from the
/// Content-Type header or an early <meta>, with sensible fallbacks.
nonisolated enum HTMLInputDecoder {
    static func decode(_ data: Data, contentType: String) -> String? {
        var encodings: [String.Encoding] = []
        if let name = charsetParameter(in: contentType) ?? metaCharset(in: data),
           let encoding = encoding(named: name) {
            encodings.append(encoding)
        }
        encodings += [.utf8, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) { return string }
        }
        return nil
    }

    private static func charsetParameter(in contentType: String) -> String? {
        guard let range = contentType.range(of: "charset=") else { return nil }
        let value = contentType[range.upperBound...]
            .prefix { !"; \"'".contains($0) }
        return value.isEmpty ? nil : String(value)
    }

    private static func metaCharset(in data: Data) -> String? {
        let prefix = String(decoding: data.prefix(2048), as: UTF8.self).lowercased()
        guard let range = prefix.range(of: "charset=") else { return nil }
        let value = prefix[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            .prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return value.isEmpty ? nil : String(value)
    }

    private static func encoding(named name: String) -> String.Encoding? {
        switch name.lowercased() {
        case "utf-8", "utf8": .utf8
        case "iso-8859-1", "latin1", "l1": .isoLatin1
        case "windows-1252", "cp1252", "x-cp1252": .windowsCP1252
        case "us-ascii", "ascii": .ascii
        case "shift_jis", "shift-jis", "sjis": .shiftJIS
        case "iso-2022-jp": .iso2022JP
        case "euc-jp": .japaneseEUC
        case "utf-16": .utf16
        default: nil
        }
    }
}
