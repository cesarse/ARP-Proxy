import CoreGraphics
import Foundation
import ImageIO

nonisolated struct JPEGTranscoder: ImageTranscoding {
    let format = ImageFormat.jpeg
    private let downscaling = LegacyImageDownscaling()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        downscaling.downscale(source, from: format, options: options)
    }
}
