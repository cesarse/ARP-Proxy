import CoreGraphics
import Foundation

/// Decides whether an image genuinely uses transparency. Decoders hand
/// back ARGB even for fully opaque WebP/AVIF photos, so trusting the
/// pixel format alone would turn photos into 256-color GIFs.
nonisolated enum TransparencyDetector {
    static func hasTransparentPixels(_ image: CGImage) -> Bool {
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
}
