import CoreGraphics
import Foundation
import ImageIO

/// Strategy: one transcoder per image format, selected by `ImageTranscoder`.
nonisolated protocol ImageTranscoding: Sendable {
    /// The format this strategy is responsible for.
    var format: ImageFormat { get }
    /// A replacement body, or nil to pass the original through unchanged.
    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage?
}
