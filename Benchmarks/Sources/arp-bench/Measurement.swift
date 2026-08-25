@testable import ARPProxyHTML
import Foundation

/// Everything one fixture-and-dialect run produced. Split into *metrics*,
/// which are reported and allowed to move, and *invariants*, which are
/// promises the README makes to the browser and must never break.
nonisolated struct Measurement: Sendable {
    let fixture: String
    let version: HTMLVersion

    let inputBytes: Int
    let outputBytes: Int
    let milliseconds: Double
    let simplified: Bool
    let outputSHA256: String
    let deterministic: Bool

    let elementCount: Int
    let illegalTags: [String: Int]
    let forbiddenTags: [String: Int]
    let httpsLeaks: Int
    let nonASCIIBytes: Int
    let images: Int
    let imagesWithoutSource: Int
    let links: Int

    var ratio: Double {
        inputBytes == 0 ? 0 : Double(outputBytes) / Double(inputBytes)
    }

    var dialectLabel: String {
        DTDVocabulary.vocabulary(for: version).name
    }

    /// Column-width friendly form of `dialectLabel` for the report table.
    var shortDialectLabel: String {
        version == .html32 ? "HTML 3.2" : "HTML 4.01"
    }

    /// The promises. A non-empty list fails the whole run — these are not
    /// preferences, they are the difference between a page a Netscape 3
    /// browser can render and one it cannot.
    var invariantFailures: [String] {
        var failures: [String] = []
        if !simplified {
            failures.append("not simplified (hit a bail-out path)")
        }
        if nonASCIIBytes > 0 {
            failures.append("\(nonASCIIBytes) non-ASCII byte(s) in output")
        }
        if httpsLeaks > 0 {
            failures.append("\(httpsLeaks) surviving https:// occurrence(s)")
        }
        if !forbiddenTags.isEmpty {
            failures.append("tags a pass should have removed: \(describe(forbiddenTags))")
        }
        if !illegalTags.isEmpty {
            failures.append("tags outside \(dialectLabel): \(describe(illegalTags))")
        }
        if !deterministic {
            failures.append("output differs between two identical runs")
        }
        return failures
    }

    private func describe(_ tags: [String: Int]) -> String {
        tags.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(6)
            .map { "<\($0.key)>×\($0.value)" }
            .joined(separator: " ")
    }
}
