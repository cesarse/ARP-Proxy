import CoreGraphics
import Foundation
import ImageIO

nonisolated struct WebPTranscoder: ImageTranscoding {
    let format = ImageFormat.webp
    private let conversion = ModernImageConversion()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        conversion.convert(source, from: format, options: options)
    }
}
