import Foundation
import SwiftSoup

/// Rebuilds the page's card grids as tables, the way a site would have been
/// built before CSS could lay one out.
///
/// This is the one pass that *adds* structure. Everything else in the pipeline
/// removes, renames or unwraps, and can only ever make the document more
/// conservative; this one commits to a reading of the page that may be wrong.
/// That asymmetry is why it is opt-in, and why `GridDetector` would rather
/// miss a grid than invent one.
nonisolated struct ReproduceLayoutPass: HTMLPass {
    private let detector = GridDetector()
    private let builder = TableLayoutBuilder()

    func run(on doc: Document) throws {
        for candidate in try detector.candidates(in: doc) {
            try builder.apply(candidate)
        }
    }
}
