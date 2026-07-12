import CoreGraphics
import Foundation
import ImageIO

nonisolated struct GIFTranscoder: ImageTranscoding {
    let format = ImageFormat.gif
    private let downscaling = LegacyImageDownscaling()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        downscaling.downscale(source, from: format, options: options)
    }
}
