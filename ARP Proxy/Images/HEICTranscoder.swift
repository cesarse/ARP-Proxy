import CoreGraphics
import Foundation
import ImageIO

nonisolated struct HEICTranscoder: ImageTranscoding {
    let format = ImageFormat.heic
    private let conversion = ModernImageConversion()

    func transcode(_ source: CGImageSource, options: TranscodeOptions) -> TranscodedImage? {
        conversion.convert(source, from: format, options: options)
    }
}
