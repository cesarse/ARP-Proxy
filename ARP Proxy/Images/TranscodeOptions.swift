import Foundation

/// User-tunable knobs handed to every transcoding strategy.
nonisolated struct TranscodeOptions: Sendable {
    var jpegQuality: Double
    var maxPixelSize: Int
}
