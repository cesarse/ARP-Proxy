import Foundation

/// A response body after downgrading, with an optional Content-Type
/// replacement and a note for the request log.
nonisolated struct TransformedBody: Sendable {
    let data: Data
    let contentTypeOverride: String?
    let note: String?
}
