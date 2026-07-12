import CoreGraphics
import Foundation
import ImageIO

nonisolated struct PNGTranscoder: ImageTranscoding {
    let format = ImageFormat.png
    private let downscaling = LegacyImageDownscaling()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        downscaling.downscale(source, from: format, options: options)
    }
}
