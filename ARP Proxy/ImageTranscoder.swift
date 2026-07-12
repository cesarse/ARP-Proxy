import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts image formats vintage browsers don't understand — WebP, AVIF,
/// HEIC — into ones they do: JPEG for opaque still images, GIF for images
/// with transparency and for animations. Formats old browsers already know
/// (JPEG, PNG, GIF) are only touched when they exceed the configured
/// maximum dimension, in which case they are downscaled too.
nonisolated enum ImageTranscoder {

    nonisolated struct TranscodedImage: Sendable {
        let data: Data
        let contentType: String
        /// Short description for the request log, e.g. "webp → jpeg".
        let note: String
    }

    /// Bodies larger than this are passed through untouched.
    private static let maxInputBytes = 24 * 1024 * 1024
    /// Animations with more frames than this are reduced to their first frame.
    private static let maxAnimationFrames = 200

    /// Formats vintage browsers can display natively; these only need help
    /// when they are too big.
    private static let legacyFormats: Set<String> = ["jpeg", "png", "gif"]

    /// Returns a JPEG or GIF replacement for the body, or nil when the body
    /// should be passed through unchanged (not an image, small enough
    /// already, or decoding failed).
    static func transcodeIfNeeded(_ data: Data, contentType: String,
                                  jpegQuality: Double, maxPixelSize: Int) -> TranscodedImage? {
        guard let sourceFormat = detectFormat(data: data, contentType: contentType),
              data.count <= maxInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        if legacyFormats.contains(sourceFormat) {
            return downscaleLegacy(source, format: sourceFormat, frameCount: frameCount,
                                   jpegQuality: jpegQuality, maxPixelSize: maxPixelSize)
        }

        if frameCount > 1, frameCount <= maxAnimationFrames {
            return encodeAnimatedGIF(source, frameCount: frameCount,
                                     note: "\(sourceFormat) → gif")
        }
        guard let image = decodeStill(source, maxPixelSize: maxPixelSize) else { return nil }
        if hasTransparentPixels(image) {
            return encodeGIF([image], delays: nil, note: "\(sourceFormat) → gif")
        }
        return encodeJPEG(image, quality: jpegQuality, note: "\(sourceFormat) → jpeg")
    }

    /// JPEG/PNG/GIF render fine on vintage browsers, but a 2800 px retina
    /// hero image will bring a 90s machine to its knees — shrink anything
    /// over the limit. Small images pass through byte-identical, and
    /// animated GIFs are never touched.
    private static func downscaleLegacy(_ source: CGImageSource, format: String,
                                        frameCount: Int, jpegQuality: Double,
                                        maxPixelSize: Int) -> TranscodedImage? {
        guard frameCount == 1,
              let size = pixelSize(source),
              max(size.width, size.height) > maxPixelSize,
              let image = decodeStill(source, maxPixelSize: maxPixelSize)
        else { return nil }
        if hasTransparentPixels(image) {
            let note = format == "gif" ? "gif downscaled" : "\(format) → gif, downscaled"
            return encodeGIF([image], delays: nil, note: note)
        }
        let note = format == "jpeg" ? "jpeg downscaled" : "\(format) → jpeg, downscaled"
        return encodeJPEG(image, quality: jpegQuality, note: note)
    }

    /// Reads the pixel dimensions from the image header without decoding.
    private static func pixelSize(_ source: CGImageSource) -> (width: Int, height: Int)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    // MARK: - Format detection

    /// Magic bytes are checked before the Content-Type header, because CDNs
    /// occasionally serve WebP under an image/jpeg label.
    private static func detectFormat(data: Data, contentType: String) -> String? {
        let header = Data(data.prefix(12))
        if header.count >= 12 {
            if header[0..<4].elementsEqual("RIFF".utf8),
               header[8..<12].elementsEqual("WEBP".utf8) {
                return "webp"
            }
            if header[4..<8].elementsEqual("ftyp".utf8) {
                let brand = String(decoding: header[8..<12], as: UTF8.self)
                if brand.hasPrefix("av") { return "avif" }
                if ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) {
                    return "heic"
                }
            }
        }
        if header.count >= 8, header[0..<8].elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "png"
        }
        if header.count >= 4, header[0..<4].elementsEqual("GIF8".utf8) {
            return "gif"
        }
        if header.count >= 3, header[0] == 0xFF, header[1] == 0xD8, header[2] == 0xFF {
            return "jpeg"
        }
        let base = contentType.split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        switch base {
        case "image/webp": return "webp"
        case "image/avif": return "avif"
        case "image/heic", "image/heif": return "heic"
        case "image/jpeg", "image/jpg", "image/pjpeg": return "jpeg"
        case "image/png", "image/x-png": return "png"
        case "image/gif": return "gif"
        default: return nil
        }
    }

    // MARK: - Decoding

    /// Decodes the first frame, downscaled to `maxPixelSize` and with EXIF
    /// orientation baked in.
    private static func decodeStill(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// True only when the image actually uses transparency. Decoders hand
    /// back ARGB even for fully opaque WebP/AVIF photos, so trusting the
    /// pixel format alone would turn photos into 256-color GIFs.
    private static func hasTransparentPixels(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        // Render downscaled and inspect the alpha bytes: averaging fully
        // opaque pixels stays 255, so any byte below 255 proves transparency.
        let width = min(image.width, 256)
        let height = min(image.height, 256)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return true }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else { return true }
        let bytes = buffer.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for pixel in 0..<(width * height) where bytes[pixel * 4 + 3] != 255 {
            return true
        }
        return false
    }

    private static func frameDelay(_ source: CGImageSource, at index: Int) -> Double {
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

    // MARK: - Encoding

    private static func encodeJPEG(_ image: CGImage, quality: Double,
                                   note: String) -> TranscodedImage? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return TranscodedImage(data: output as Data, contentType: "image/jpeg", note: note)
    }

    private static func encodeAnimatedGIF(_ source: CGImageSource, frameCount: Int,
                                          note: String) -> TranscodedImage? {
        var frames: [CGImage] = []
        var delays: [Double] = []
        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            frames.append(frame)
            delays.append(frameDelay(source, at: index))
        }
        return encodeGIF(frames, delays: delays, note: note)
    }

    /// Single- or multi-frame GIF; `delays` non-nil makes it a looping animation.
    private static func encodeGIF(_ frames: [CGImage], delays: [Double]?,
                                  note: String) -> TranscodedImage? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.gif.identifier as CFString, frames.count, nil)
        else { return nil }

        if let delays {
            let fileProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
            ]
            CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
            for (frame, delay) in zip(frames, delays) {
                let frameProperties: [CFString: Any] = [
                    kCGImagePropertyGIFDictionary: [
                        kCGImagePropertyGIFDelayTime: delay,
                        kCGImagePropertyGIFUnclampedDelayTime: delay,
                    ],
                ]
                CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
            }
        } else {
            for frame in frames {
                CGImageDestinationAddImage(destination, frame, nil)
            }
        }

        guard CGImageDestinationFinalize(destination) else { return nil }
        return TranscodedImage(data: output as Data, contentType: "image/gif", note: note)
    }
}
