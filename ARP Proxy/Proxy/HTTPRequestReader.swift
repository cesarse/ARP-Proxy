import Foundation

/// Reads one HTTP/1.x request from the browser socket and parses it.
nonisolated struct HTTPRequestReader {
    private static let headerSeparator = Data("\r\n\r\n".utf8)
    private static let maxHeaderBytes = 128 * 1024
    private static let maxBodyBytes = 32 * 1024 * 1024

    private let socket: BrowserSocket

    init(socket: BrowserSocket) {
        self.socket = socket
    }

    /// nil means the client connected and closed without sending anything
    /// (browsers preconnect); not worth reporting.
    func read() async throws -> HTTPRequest? {
        guard let (headData, remainder) = try await readHead() else { return nil }
        var request = try parse(headData)
        request.body = try await readBody(startingWith: remainder,
                                          contentLength: contentLength(of: request))
        return request
    }

    private func readHead() async throws -> (head: Data, remainder: Data)? {
        var buffer = Data()
        while true {
            if buffer.count > Self.maxHeaderBytes { throw ProxyError.headersTooLarge }
            if let separatorRange = buffer.range(of: Self.headerSeparator) {
                return (Data(buffer[..<separatorRange.lowerBound]),
                        Data(buffer[separatorRange.upperBound...]))
            }
            guard let chunk = try await socket.receiveChunk() else {
                if buffer.isEmpty { return nil }
                throw ProxyError.unexpectedEOF
            }
            buffer.append(chunk)
        }
    }

    private func parse(_ headData: Data) throws -> HTTPRequest {
        guard let head = String(data: headData, encoding: .isoLatin1) else {
            throw ProxyError.badRequest
        }
        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { throw ProxyError.badRequest }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { throw ProxyError.badRequest }
        return HTTPRequest(method: parts[0], target: parts[1],
                           version: parts.count >= 3 ? parts[2] : "HTTP/1.0",
                           headers: parseHeaders(lines.dropFirst()), body: Data())
    }

    private func parseHeaders(_ lines: some Sequence<String>) -> [HTTPHeader] {
        var headers: [HTTPHeader] = []
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers.append(HTTPHeader(name: name, value: value))
        }
        return headers
    }

    private func contentLength(of request: HTTPRequest) -> Int {
        guard let value = request.value(for: "Content-Length"), let length = Int(value) else {
            return 0
        }
        return length
    }

    private func readBody(startingWith remainder: Data, contentLength: Int) async throws -> Data {
        guard contentLength > 0 else { return Data() }
        guard contentLength <= Self.maxBodyBytes else { throw ProxyError.bodyTooLarge }
        var body = remainder
        while body.count < contentLength {
            guard let chunk = try await socket.receiveChunk() else { throw ProxyError.unexpectedEOF }
            body.append(chunk)
        }
        return body.prefix(contentLength)
    }
}
