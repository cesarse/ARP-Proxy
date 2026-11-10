import Foundation
@testable import ARPProxyHTML

extension HTTPRequest {
    /// A browser request with sensible defaults, so each test states only
    /// the parts it is about.
    static func fixture(method: String = "GET",
                        target: String = "http://example.com/",
                        headers: [(String, String)] = [],
                        body: Data = Data()) -> HTTPRequest {
        HTTPRequest(method: method, target: target, version: "HTTP/1.0",
                    headers: headers.map { HTTPHeader(name: $0.0, value: $0.1) },
                    body: body)
    }
}
