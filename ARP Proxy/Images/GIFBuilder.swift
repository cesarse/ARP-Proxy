import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builder that assembles a single- or multi-frame GIF around
/// CGImageDestination's create → configure → add frames → finalize dance.
nonisolated final class GIFBuilder {
    private let output = NSMutableData()
    private let destination: CGImageDestination

    init?(frameCount: Int) {
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.gif.identifier as CFString, frameCount, nil)
        else { return nil }
        self.destination = destination
    }

    /// Marks the animation as looping forever. Call before adding frames.
    @discardableResult
    func loopingForever() -> GIFBuilder {
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        return self
    }

    /// Appends a frame; a `delay` (in seconds) makes it an animation frame.
    @discardableResult
    func addFrame(_ image: CGImage, delay: Double? = nil) -> GIFBuilder {
        if let delay {
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: delay,
                    kCGImagePropertyGIFUnclampedDelayTime: delay,
                ],
            ]
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        } else {
            CGImageDestinationAddImage(destination, image, nil)
        }
        return self
    }

    /// Finalizes the file and returns the encoded GIF.
    func build() -> Data? {
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
