import Foundation
import SwiftSoup

/// First-class collection of passes, run in order. The order carries
/// meaning — see `HTMLSimplificationEngine.makePipeline()`.
nonisolated struct HTMLPassPipeline: Sendable {
    private let passes: [any HTMLPass]

    init(_ passes: [any HTMLPass]) {
        self.passes = passes
    }

    func run(on doc: Document) throws {
        for pass in passes {
            try pass.run(on: doc)
        }
    }
}
