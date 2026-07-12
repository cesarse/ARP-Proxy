import CoreGraphics
import Foundation
import ImageIO

/// Decodes the first frame of an image source, downscaled to a maximum
/// pixel size and with EXIF orientation baked in.
nonisolated enum StillImageDecoder {
    static func decode(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
