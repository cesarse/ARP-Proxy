import CoreGraphics
import Foundation
import ImageIO

/// Downscaling shared by formats vintage browsers display natively; the
/// only help they need is shrinking when a retina-sized original would
/// crush a 90s machine. Images within the limit pass through
/// byte-identical, and animated GIFs are never touched.
nonisolated struct LegacyImageDownscaling: Sendable {
    func downscale(_ source: CGImageSource, from format: ImageFormat,
                   options: TranscodeOptions) -> TranscodedImage? {
        guard CGImageSourceGetCount(source) == 1,
              let size = ImageMetadataReader.pixelSize(of: source),
              max(size.width, size.height) > options.maxPixelSize,
              let image = StillImageDecoder.decode(source, maxPixelSize: options.maxPixelSize)
        else { return nil }
        if TransparencyDetector.hasTransparentPixels(image) {
            guard let data = GIFBuilder(frameCount: 1)?.addFrame(image).build() else { return nil }
            let note = format == .gif ? "gif downscaled" : "\(format.rawValue) → gif, downscaled"
            return TranscodedImage(data: data, contentType: "image/gif", note: note)
        }
        guard let data = JPEGEncoder.encode(image, quality: options.jpegQuality) else { return nil }
        let note = format == .jpeg ? "jpeg downscaled" : "\(format.rawValue) → jpeg, downscaled"
        return TranscodedImage(data: data, contentType: "image/jpeg", note: note)
    }
}
