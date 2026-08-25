import Foundation

/// Locates the benchmark directory. Walks up from the working directory so
/// `swift run arp-bench` works from anywhere in the checkout, and falls back
/// to the source location for the case where it is run from outside the repo.
nonisolated struct BenchmarkPaths: Sendable {
    let root: URL

    var fixtures: URL { root.appending(path: "Fixtures") }
    var golden: URL { root.appending(path: "Golden/golden.json") }
    var output: URL { root.appending(path: "Output") }

    static func locate() -> BenchmarkPaths? {
        let candidates = [URL(filePath: FileManager.default.currentDirectoryPath)]
            + [URL(filePath: #filePath)
                .deletingLastPathComponent()   // arp-bench
                .deletingLastPathComponent()   // Sources
                .deletingLastPathComponent()]  // Benchmarks
        for candidate in candidates {
            if let found = search(from: candidate) { return found }
        }
        return nil
    }

    private static func search(from start: URL) -> BenchmarkPaths? {
        var directory = start.standardizedFileURL
        for _ in 0..<8 {
            for root in [directory, directory.appending(path: "Benchmarks")] {
                let manifest = root.appending(path: "Fixtures/manifest.json")
                if FileManager.default.fileExists(atPath: manifest.path) {
                    return BenchmarkPaths(root: root)
                }
            }
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { break }
            directory = parent
        }
        return nil
    }
}
