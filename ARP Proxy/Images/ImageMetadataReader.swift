import CoreGraphics
import Foundation
import ImageIO

/// Reads header metadata — dimensions, animation frame delays — without
/// decoding any pixel data.
nonisolated enum ImageMetadataReader {
    static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    static func frameDelay(of source: CGImageSource, at index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [CFString: Any]
        else { return 0.1 }
        let candidates: [(CFString, CFString, CFString)] = [
            (kCGImagePropertyWebPDictionary,
             kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
            (kCGImagePropertyGIFDictionary,
             kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
            (kCGImagePropertyHEICSDictionary,
             kCGImagePropertyHEICSUnclampedDelayTime, kCGImagePropertyHEICSDelayTime),
        ]
        for (dictionary, unclamped, clamped) in candidates {
            guard let info = properties[dictionary] as? [CFString: Any] else { continue }
            if let delay = info[unclamped] as? Double, delay > 0 { return delay }
            if let delay = info[clamped] as? Double, delay > 0 { return delay }
        }
        return 0.1
    }
}
