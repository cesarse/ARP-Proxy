import Foundation

/// The product of a successful transcode: replacement body, its type, and
/// a note for the request log.
nonisolated struct TranscodedImage: Sendable {
    let data: Data
    let contentType: String
    /// Short description for the request log, e.g. "webp → jpeg".
    let note: String
}
