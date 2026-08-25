@testable import ARPProxyHTML
import Foundation

// Benchmarks the HTML simplification pipeline against frozen captures of the
// real web. Metrics are reported; invariants are enforced. Simplified output
// is always written to Benchmarks/Output, which is committed — so when a
// digest drifts, `git diff Benchmarks/Output` shows exactly what changed
// instead of just telling you that something did.

struct Options {
    var update = false
    var only: String?
    var versions: [HTMLVersion] = HTMLVersion.allCases

    static func parse(_ arguments: [String]) -> Options? {
        var options = Options()
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--update":
                options.update = true
            case "--only":
                index += 1
                guard index < arguments.count else { return nil }
                options.only = arguments[index]
            case "--dialect":
                index += 1
                guard index < arguments.count else { return nil }
                switch arguments[index] {
                case "32", "3.2", "html32": options.versions = [.html32]
                case "401", "4.01", "html401": options.versions = [.html401]
                default: return nil
                }
            case "--help", "-h":
                return nil
            default:
                return nil
            }
            index += 1
        }
        return options
    }
}

let usage = """
    arp-bench — benchmark the HTML simplification pipeline

    USAGE
      swift run arp-bench [--only <fixture>] [--dialect 32|401] [--update]

      --only <fixture>   Run a single fixture (its manifest name).
      --dialect 32|401   Run one dialect instead of both.
      --update           Accept the current output as the new golden.

    Exits non-zero when an invariant breaks or a digest drifts. Refresh the
    corpus with Benchmarks/capture-fixtures.sh.
    """

guard let options = Options.parse(Array(CommandLine.arguments.dropFirst())) else {
    print(usage)
    exit(2)
}

guard let paths = BenchmarkPaths.locate() else {
    FileHandle.standardError.write(Data(
        "arp-bench: could not find Benchmarks/Fixtures/manifest.json.\n".utf8))
    exit(2)
}

do {
    var fixtures = try Fixture.load(from: paths.fixtures)
    if let only = options.only {
        fixtures = fixtures.filter { $0.name == only }
        guard !fixtures.isEmpty else {
            FileHandle.standardError.write(Data("arp-bench: no fixture named '\(only)'.\n".utf8))
            exit(2)
        }
    }

    try FileManager.default.createDirectory(at: paths.output, withIntermediateDirectories: true)

    let measurer = Measurer()
    var measurements: [Measurement] = []
    for fixture in fixtures {
        for version in options.versions {
            let (measurement, output) = try measurer.measure(fixture, version: version)
            measurements.append(measurement)
            try output.write(to: paths.output
                .appending(path: "\(fixture.name).\(version.rawValue).html"))
        }
    }

    let report = Report(measurements: measurements,
                        goldens: GoldenStore.load(from: paths.golden))
    print(report.text)

    if options.update {
        try FileManager.default.createDirectory(
            at: paths.golden.deletingLastPathComponent(), withIntermediateDirectories: true)
        try GoldenStore.save(measurements.map(GoldenRecord.init), to: paths.golden)
        print("\nAccepted \(measurements.count) result(s) as golden.")
        exit(measurements.allSatisfy { $0.invariantFailures.isEmpty } ? 0 : 1)
    }
    exit(report.hasFailures ? 1 : 0)
} catch {
    FileHandle.standardError.write(Data("arp-bench: \(error)\n".utf8))
    exit(2)
}
