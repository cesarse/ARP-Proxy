import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts image formats vintage browsers don't understand — WebP, AVIF,
/// HEIC — into ones they do: JPEG for opaque still images, GIF for images
/// with transparency and for animations.
nonisolated enum ImageTranscoder {

    nonisolated struct TranscodedImage: Sendable {
        let data: Data
        let contentType: String
        /// Short description for the request log, e.g. "webp → jpeg".
        let note: String
    }

    /// Bodies larger than this are passed through untouched.
    private static let maxInputBytes = 24 * 1024 * 1024
    /// Still images are downscaled to fit vintage-era screens (and RAM).
    private static let maxStillPixelSize = 2048
    /// Animations with more frames than this are reduced to their first frame.
    private static let maxAnimationFrames = 200

    private static let transcodableTypes: Set<String> = [
        "image/webp", "image/avif", "image/heic", "image/heif",
    ]

    /// Returns a JPEG or GIF replacement for the body, or nil when the body
    /// is not a transcodable image (or decoding fails and it should be
    /// passed through unchanged).
    static func transcodeIfNeeded(_ data: Data, contentType: String) -> TranscodedImage? {
        guard let sourceFormat = detectFormat(data: data, contentType: contentType),
              data.count <= maxInputBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }
        if frameCount > 1, frameCount <= maxAnimationFrames {
            return encodeAnimatedGIF(source, frameCount: frameCount, from: sourceFormat)
        }
        guard let image = decodeStill(source) else { return nil }
        if hasTransparentPixels(image) {
            return encodeGIF([image], delays: nil, from: sourceFormat)
        }
        return encodeJPEG(image, from: sourceFormat)
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
        let base = contentType.split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if transcodableTypes.contains(base) {
            return String(base.dropFirst("image/".count))
        }
        return nil
    }

    // MARK: - Decoding

    /// Decodes the first frame, downscaled to `maxStillPixelSize` and with
    /// EXIF orientation baked in.
    private static func decodeStill(_ source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxStillPixelSize,
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

    private static func encodeJPEG(_ image: CGImage, from sourceFormat: String) -> TranscodedImage? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return TranscodedImage(data: output as Data, contentType: "image/jpeg",
                               note: "\(sourceFormat) → jpeg")
    }

    private static func encodeAnimatedGIF(_ source: CGImageSource, frameCount: Int,
                                          from sourceFormat: String) -> TranscodedImage? {
        var frames: [CGImage] = []
        var delays: [Double] = []
        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            frames.append(frame)
            delays.append(frameDelay(source, at: index))
        }
        return encodeGIF(frames, delays: delays, from: sourceFormat)
    }

    /// Single- or multi-frame GIF; `delays` non-nil makes it a looping animation.
    private static func encodeGIF(_ frames: [CGImage], delays: [Double]?,
                                  from sourceFormat: String) -> TranscodedImage? {
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
        return TranscodedImage(data: output as Data, contentType: "image/gif",
                               note: "\(sourceFormat) → gif")
    }
}
