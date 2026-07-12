import Foundation
import ImageIO

/// Facade over the per-format strategies: sniffs the image format, looks
/// up the matching transcoder in the registry and runs it.
nonisolated enum ImageTranscoder {

    /// Registry of strategies, keyed by the format each one handles.
    private static let transcoders: [ImageFormat: any ImageTranscoding] = {
        let all: [any ImageTranscoding] = [
            WebPTranscoder(), AVIFTranscoder(), HEICTranscoder(),
            JPEGTranscoder(), PNGTranscoder(), GIFTranscoder(),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.format, $0) })
    }()

    /// Returns a replacement body, or nil when the body should be passed
    /// through unchanged (not an image, small enough already, or the
    /// strategy could not decode it).
    static func transcodeIfNeeded(_ data: Data, contentType: String,
                                  jpegQuality: Double, maxPixelSize: Int) -> TranscodedImage? {
        guard data.count <= TranscodePolicy.maxInputBytes,
              let format = ImageFormat.detect(data: data, contentType: contentType),
              let transcoder = transcoders[format],
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        let options = TranscodeOptions(jpegQuality: jpegQuality, maxPixelSize: maxPixelSize)
        return transcoder.transcode(source, options: options)
    }
}
