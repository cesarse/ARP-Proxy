import CoreGraphics
import Foundation
import ImageIO

nonisolated struct AVIFTranscoder: ImageTranscoding {
    let format = ImageFormat.avif
    private let conversion = ModernImageConversion()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        conversion.convert(source, from: format, options: options)
    }
}
