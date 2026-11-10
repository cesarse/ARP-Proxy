import Foundation

/// Renders the run as a table plus a verdict. Metrics are informational and
/// expected to move; the verdict is driven only by broken invariants and by
/// digests that drifted without `--update`.
nonisolated struct Report: Sendable {
    let measurements: [Measurement]
    let goldens: [String: GoldenRecord]

    private static let columns = [
        ("fixture", 20), ("dialect", 10), ("tables", 7), ("input", 11),
        ("output", 10), ("ratio", 7), ("ms", 8), ("elements", 9), ("img", 9),
        ("links", 7), ("golden", 8),
    ]

    var text: String {
        var lines: [String] = []
        lines.append(Self.columns.map { pad($0.0, $0.1, right: $0.0 != "fixture") }
            .joined(separator: " "))
        lines.append(String(repeating: "-",
                            count: Self.columns.reduce(0) { $0 + $1.1 + 1 } - 1))
        for measurement in measurements {
            lines.append(row(for: measurement))
        }
        lines.append("")
        lines.append(contentsOf: driftSection())
        lines.append(contentsOf: failureSection())
        lines.append(verdict)
        return lines.joined(separator: "\n")
    }

    var hasFailures: Bool {
        !measurements.allSatisfy { $0.invariantFailures.isEmpty } || !drifted.isEmpty
    }

    /// Pairs whose digest no longer matches the accepted output. New pairs are
    /// not drift — there was nothing to disagree with.
    var drifted: [Measurement] {
        measurements.filter { measurement in
            guard let golden = goldens[GoldenRecord(measurement).key] else { return false }
            return golden.outputSHA256 != measurement.outputSHA256
        }
    }

    // MARK: - Sections

    private func row(for m: Measurement) -> String {
        let images = m.imagesWithoutSource == 0
            ? "\(m.images)" : "\(m.images) (\(m.imagesWithoutSource)!)"
        let cells: [(String, Int)] = [
            (m.fixture, 20), (m.shortDialectLabel, 10),
            (m.layout ? "on" : "-", 7),
            (grouped(m.inputBytes), 11), (grouped(m.outputBytes), 10),
            (String(format: "%.1f%%", m.ratio * 100), 7),
            (String(format: "%.0f", m.milliseconds), 8),
            (grouped(m.elementCount), 9), (images, 9), (grouped(m.links), 7),
            (goldenStatus(m), 8),
        ]
        return zip(cells, Self.columns)
            .map { pad($0.0.0, $0.0.1, right: $0.1.0 != "fixture") }
            .joined(separator: " ")
    }

    private func goldenStatus(_ m: Measurement) -> String {
        guard let golden = goldens[GoldenRecord(m).key] else { return "new" }
        return golden.outputSHA256 == m.outputSHA256 ? "ok" : "DRIFT"
    }

    private func driftSection() -> [String] {
        guard !drifted.isEmpty else { return [] }
        var lines = ["Output changed since the accepted golden:"]
        for m in drifted {
            let golden = goldens[GoldenRecord(m).key]!
            let delta = m.outputBytes - golden.outputBytes
            let sign = delta >= 0 ? "+" : ""
            lines.append("  \(m.fixture) [\(m.modeLabel)]  "
                + "\(grouped(golden.outputBytes)) -> \(grouped(m.outputBytes)) bytes "
                + "(\(sign)\(grouped(delta)))")
        }
        lines.append("  Review the diff in Benchmarks/Output, then accept with --update.")
        lines.append("")
        return lines
    }

    private func failureSection() -> [String] {
        let failing = measurements.filter { !$0.invariantFailures.isEmpty }
        guard !failing.isEmpty else { return [] }
        var lines = ["Broken invariants:"]
        for m in failing {
            lines.append("  \(m.fixture) [\(m.modeLabel)]")
            for failure in m.invariantFailures {
                lines.append("      - \(failure)")
            }
        }
        lines.append("")
        return lines
    }

    private var verdict: String {
        let invariantFailures = measurements.filter { !$0.invariantFailures.isEmpty }.count
        if invariantFailures == 0 && drifted.isEmpty {
            return "PASS  \(measurements.count) runs, all invariants held, no drift."
        }
        var parts: [String] = []
        if invariantFailures > 0 { parts.append("\(invariantFailures) with broken invariants") }
        if !drifted.isEmpty { parts.append("\(drifted.count) drifted") }
        return "FAIL  \(measurements.count) runs: " + parts.joined(separator: ", ") + "."
    }

    // MARK: - Formatting

    private func pad(_ text: String, _ width: Int, right: Bool) -> String {
        guard text.count < width else { return text }
        let padding = String(repeating: " ", count: width - text.count)
        return right ? padding + text : text + padding
    }

    private func grouped(_ value: Int) -> String {
        let digits = Array(String(abs(value)).reversed())
        let chunks = stride(from: 0, to: digits.count, by: 3)
            .map { String(digits[$0..<min($0 + 3, digits.count)]) }
        return (value < 0 ? "-" : "") + String(chunks.joined(separator: ",").reversed())
    }
}
