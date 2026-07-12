import Foundation

/// Failures while reading or parsing a browser request.
nonisolated enum ProxyError: Error {
    case headersTooLarge
    case bodyTooLarge
    case unexpectedEOF
    case badRequest
}
