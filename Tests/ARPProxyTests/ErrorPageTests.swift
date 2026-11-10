import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Error page")
struct ErrorPageTests {

    private let page = ErrorPage(status: 502, title: "Bad Gateway",
                                 message: "Could not reach example.com.")

    /// Splits the encoded response at the blank line ending the head.
    private func split() -> (head: String, body: String) {
        let response = String(decoding: page.encodedResponse(), as: UTF8.self)
        let parts = response.components(separatedBy: "\r\n\r\n")
        return (parts[0], parts.dropFirst().joined(separator: "\r\n\r\n"))
    }

    @Test("The head is a complete HTTP/1.0 response head")
    func head() {
        let lines = split().head.components(separatedBy: "\r\n")
        #expect(lines.first == "HTTP/1.0 502 Bad Gateway")
        #expect(lines.contains("Content-Type: text/html"))
        #expect(lines.contains("Connection: close"))
    }

    @Test("Content-Length matches the body's byte count")
    func contentLength() {
        let (head, body) = split()
        #expect(head.components(separatedBy: "\r\n")
                    .contains("Content-Length: \(Data(body.utf8).count)"))
    }

    @Test("The body shows the title and the message")
    func body() {
        let body = split().body
        #expect(body.contains("<title>Bad Gateway</title>"))
        #expect(body.contains("<h1>Bad Gateway</h1>"))
        #expect(body.contains("Could not reach example.com."))
    }
}
