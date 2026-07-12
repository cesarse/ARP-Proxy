import CoreGraphics
import Foundation
import ImageIO

/// Conversion shared by formats vintage browsers can't display at all:
/// animations become looping GIFs, stills become JPEG when opaque or GIF
/// when genuinely transparent.
nonisolated struct ModernImageConversion: Sendable {
    func convert(_ source: CGImageSource, from format: ImageFormat,
                 options: TranscodeOptions) -> TranscodedImage? {
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }
        if frameCount > 1, frameCount <= TranscodePolicy.maxAnimationFrames {
            return convertAnimation(source, frameCount: frameCount, from: format)
        }
        return convertStill(source, from: format, options: options)
    }

    private func convertStill(_ source: CGImageSource, from format: ImageFormat,
                              options: TranscodeOptions) -> TranscodedImage? {
        guard let image = StillImageDecoder.decode(source, maxPixelSize: options.maxPixelSize)
        else { return nil }
        if TransparencyDetector.hasTransparentPixels(image) {
            guard let data = GIFBuilder(frameCount: 1)?.addFrame(image).build() else { return nil }
            return TranscodedImage(data: data, contentType: "image/gif",
                                   note: "\(format.rawValue) → gif")
        }
        guard let data = JPEGEncoder.encode(image, quality: options.jpegQuality) else { return nil }
        return TranscodedImage(data: data, contentType: "image/jpeg",
                               note: "\(format.rawValue) → jpeg")
    }

    private func convertAnimation(_ source: CGImageSource, frameCount: Int,
                                  from format: ImageFormat) -> TranscodedImage? {
        guard let builder = GIFBuilder(frameCount: frameCount) else { return nil }
        builder.loopingForever()
        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            builder.addFrame(frame, delay: ImageMetadataReader.frameDelay(of: source, at: index))
        }
        guard let data = builder.build() else { return nil }
        return TranscodedImage(data: data, contentType: "image/gif",
                               note: "\(format.rawValue) → gif")
    }
}
