@testable import ARPProxyHTML
import CryptoKit
import Foundation
import SwiftSoup

/// Runs one fixture through the real production entry point and measures what
/// came out. It calls `BodyTransformer` rather than reaching for the engine
/// directly, so the benchmark exercises the same path a proxied response
/// takes — HTML simplification *and* the https→http rewrite that follows it.
nonisolated struct Measurer: Sendable {

    func measure(_ fixture: Fixture, version: HTMLVersion) throws -> (Measurement, Data) {
        var settings = ProxySettings()
        settings.simplifyHTML = true
        settings.htmlVersion = version
        let transformer = BodyTransformer(settings: settings)

        let clock = ContinuousClock()
        let start = clock.now
        let transformed = transformer.transform(fixture.body,
                                                contentType: fixture.contentType)
        let elapsed = clock.now - start
        let output = transformed.data

        // A second identical run: pass ordering that depends on dictionary or
        // set iteration order would show up here and nowhere else.
        let second = transformer.transform(fixture.body, contentType: fixture.contentType)

        let vocabulary = DTDVocabulary.vocabulary(for: version)
        let tags = tagCounts(in: output)

        let measurement = Measurement(
            fixture: fixture.name,
            version: version,
            inputBytes: fixture.body.count,
            outputBytes: output.count,
            milliseconds: Double(elapsed.components.attoseconds) / 1e15
                + Double(elapsed.components.seconds) * 1000,
            simplified: transformed.note == "simplified",
            outputSHA256: Self.digest(output),
            deterministic: second.data == output,
            elementCount: tags.values.reduce(0, +),
            illegalTags: tags.filter { !vocabulary.elements.contains($0.key) },
            forbiddenTags: tags.filter { DTDVocabulary.forbidden.contains($0.key) },
            httpsLeaks: Self.occurrences(of: "https://", in: output),
            nonASCIIBytes: output.reduce(into: 0) { $0 += $1 >= 0x80 ? 1 : 0 },
            images: try count(in: output, matching: "img"),
            imagesWithoutSource: try countImagesWithoutSource(in: output),
            links: try count(in: output, matching: "a[href]"))

        return (measurement, output)
    }

    // MARK: - Output inspection

    private func document(_ output: Data) throws -> Document {
        try SwiftSoup.parse(String(decoding: output, as: UTF8.self))
    }

    /// Counts opening tags in the serialized bytes rather than in a re-parse.
    /// Re-parsing measures the wrong document: SwiftSoup performs HTML5 tree
    /// construction, so it silently re-inserts a `<tbody>` into every table
    /// and would report tags the browser never receives. The bytes are what
    /// we actually send, and a vintage browser scans tags much like this.
    ///
    /// Safe against `<` in text and attributes because the serializer escapes
    /// those; `</close>`, `<!doctype` and comments yield no name and are
    /// skipped.
    private func tagCounts(in output: Data) -> [String: Int] {
        var counts: [String: Int] = [:]
        let bytes = Array(output)
        var index = 0
        while index < bytes.count {
            guard bytes[index] == UInt8(ascii: "<") else {
                index += 1
                continue
            }
            var cursor = index + 1
            var name: [UInt8] = []
            while cursor < bytes.count,
                  Self.isNameByte(bytes[cursor], isFirst: name.isEmpty) {
                name.append(Self.lowercased(bytes[cursor]))
                cursor += 1
            }
            if !name.isEmpty {
                counts[String(decoding: name, as: UTF8.self), default: 0] += 1
            }
            index = max(cursor, index + 1)
        }
        return counts
    }

    private static func isNameByte(_ byte: UInt8, isFirst: Bool) -> Bool {
        let lower = byte | 0x20
        if lower >= UInt8(ascii: "a") && lower <= UInt8(ascii: "z") { return true }
        guard !isFirst else { return false }
        return (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == UInt8(ascii: "-")
    }

    private static func lowercased(_ byte: UInt8) -> UInt8 {
        (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) ? byte | 0x20 : byte
    }

    private func count(in output: Data, matching selector: String) throws -> Int {
        try document(output).select(selector).count
    }

    /// An <img> a vintage browser cannot draw: no src at all, or one left as a
    /// data: URI that predates the browsers this proxy serves.
    private func countImagesWithoutSource(in output: Data) throws -> Int {
        try document(output).select("img").array().filter { image in
            let source = (try? image.attr("src")) ?? ""
            return source.isEmpty || source.hasPrefix("data:")
        }.count
    }

    // MARK: - Primitives

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func occurrences(of needle: String, in haystack: Data) -> Int {
        let pattern = Data(needle.utf8)
        var count = 0
        var index = haystack.startIndex
        while let range = haystack.range(of: pattern, in: index..<haystack.endIndex) {
            count += 1
            index = range.upperBound
        }
        return count
    }
}
