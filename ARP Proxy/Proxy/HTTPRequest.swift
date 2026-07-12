import Foundation

/// A parsed HTTP/1.x request as sent by the vintage browser.
nonisolated struct HTTPRequest: Sendable {
    var method: String
    var target: String
    var version: String
    var headers: [HTTPHeader]
    var body: Data

    func value(for name: String) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}
