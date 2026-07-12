import Foundation

/// One request header, name and value.
nonisolated struct HTTPHeader: Sendable {
    let name: String
    let value: String
}
