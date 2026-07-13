import Foundation

/// Replaces every `https://` with `http://` in textual bodies so that
/// links, redirects and stylesheets keep flowing through the proxy.
nonisolated enum SchemeRewriter {
    static func rewrite(_ data: Data) -> Data {
        let https = Data("https://".utf8)
        let http = Data("http://".utf8)
        var result = Data()
        result.reserveCapacity(data.count)
        var index = data.startIndex
        while let range = data.range(of: https, in: index..<data.endIndex) {
            result.append(data[index..<range.lowerBound])
            result.append(http)
            index = range.upperBound
        }
        result.append(data[index..<data.endIndex])
        return result
    }
}
