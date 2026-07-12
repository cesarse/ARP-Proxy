import Foundation
import Network

/// One accepted browser connection: reads a single HTTP/1.x proxy request,
/// fetches the resource over HTTPS (falling back to plain HTTP), and writes
/// back a downgraded HTTP/1.0 response that vintage browsers understand.
nonisolated final class ProxyConnection: @unchecked Sendable {

    nonisolated struct HTTPRequest: Sendable {
        var method: String
        var target: String
        var version: String
        var headers: [(name: String, value: String)]
        var body: Data

        func value(for name: String) -> String? {
            headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }

    nonisolated enum ProxyError: Error {
        case headersTooLarge
        case bodyTooLarge
        case unexpectedEOF
        case badRequest
    }

    private let connection: NWConnection
    private let log: @Sendable (LogEntry) -> Void

    init(connection: NWConnection, log: @escaping @Sendable (LogEntry) -> Void) {
        self.connection = connection
        self.log = log
    }

    // MARK: - Upstream session

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // Cookies belong to the vintage browser, not to this proxy.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    /// Redirects are passed through to the browser (with the Location header
    /// rewritten to http://) instead of being followed by URLSession.
    private nonisolated final class PassThroughRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }
    }

    // MARK: - Header policies

    private static let droppedRequestHeaders: Set<String> = [
        "connection", "proxy-connection", "proxy-authorization", "keep-alive",
        "te", "trailer", "transfer-encoding", "upgrade",
        "accept-encoding", "host", "content-length", "upgrade-insecure-requests",
    ]

    private static let droppedResponseHeaders: Set<String> = [
        "connection", "keep-alive", "proxy-authenticate", "proxy-connection",
        "transfer-encoding", "upgrade", "trailer",
        "content-encoding", "content-length",
        "strict-transport-security", "content-security-policy",
        "content-security-policy-report-only", "x-content-security-policy",
        "alt-svc", "x-frame-options", "permissions-policy", "report-to", "nel",
        "cross-origin-opener-policy", "cross-origin-embedder-policy",
        "cross-origin-resource-policy",
    ]

    private static let rewritableContentTypes: [String] = [
        "text/html", "application/xhtml+xml", "text/css",
        "text/javascript", "application/javascript", "application/x-javascript",
    ]

    private static let reasonPhrases: [Int: String] = [
        200: "OK", 201: "Created", 204: "No Content", 206: "Partial Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 410: "Gone", 429: "Too Many Requests",
        500: "Internal Server Error", 502: "Bad Gateway", 503: "Service Unavailable",
        504: "Gateway Timeout",
    ]

    // MARK: - Lifecycle

    func run() async {
        connection.start(queue: DispatchQueue(label: "RetroProxy.connection"))
        do {
            // nil means the client connected and closed without sending anything
            // (browsers preconnect); not worth logging.
            if let request = try await readRequest() {
                await handle(request)
            }
        } catch {
            await sendSimplePage(status: 400, title: "Bad Request",
                                 message: "RetroProxy could not parse the request.")
        }
        connection.cancel()
    }

    // MARK: - Request handling

    private func handle(_ request: HTTPRequest) async {
        if request.method.uppercased() == "CONNECT" {
            await sendSimplePage(
                status: 501, title: "HTTPS Tunneling Not Supported",
                message: "Request the page with http:// instead of https://. "
                    + "RetroProxy upgrades the connection to HTTPS for you.")
            log(LogEntry(method: request.method, url: request.target,
                         status: 501, note: "CONNECT rejected"))
            return
        }

        guard let url = resolveURL(for: request) else {
            await sendSimplePage(status: 400, title: "Bad Request",
                                 message: "The request target could not be understood.")
            log(LogEntry(method: request.method, url: request.target,
                         status: 400, note: "unparseable target"))
            return
        }

        var lastError: Error?
        for candidate in upstreamCandidates(for: url) {
            do {
                let (data, response) = try await Self.session.data(
                    for: makeUpstreamRequest(url: candidate, from: request),
                    delegate: PassThroughRedirects())
                guard let http = response as? HTTPURLResponse else {
                    throw ProxyError.badRequest
                }
                await deliver(http, body: data, request: request, upstream: candidate)
                return
            } catch {
                lastError = error
            }
        }

        let message = lastError.map { "\($0.localizedDescription)" } ?? "Unknown error."
        await sendSimplePage(status: 502, title: "Bad Gateway",
                             message: "Could not reach \(url.host ?? "the server"): \(message)")
        log(LogEntry(method: request.method, url: request.target,
                     status: 502, note: message))
    }

    /// Absolute-form proxy targets (`GET http://host/path`) are used as-is;
    /// origin-form targets (`GET /path` plus a Host header) are also accepted
    /// so the app can act as a plain gateway.
    private func resolveURL(for request: HTTPRequest) -> URL? {
        let target = request.target
        if target.lowercased().hasPrefix("http://") || target.lowercased().hasPrefix("https://") {
            return URL(string: target)
        }
        if target.hasPrefix("/"), let host = request.value(for: "Host") {
            return URL(string: "http://\(host)\(target)")
        }
        return nil
    }

    /// The "remove the S" trick in reverse: the browser asks for http://,
    /// we try https:// first and fall back to the original URL.
    private func upstreamCandidates(for url: URL) -> [URL] {
        guard url.scheme?.lowercased() == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.port == nil || components.port == 80
        else { return [url] }
        components.scheme = "https"
        components.port = nil
        guard let upgraded = components.url else { return [url] }
        return [upgraded, url]
    }

    private func makeUpstreamRequest(url: URL, from request: HTTPRequest) -> URLRequest {
        var upstream = URLRequest(url: url)
        upstream.httpMethod = request.method
        for (name, value) in request.headers
        where !Self.droppedRequestHeaders.contains(name.lowercased()) {
            upstream.addValue(value, forHTTPHeaderField: name)
        }
        if !request.body.isEmpty {
            upstream.httpBody = request.body
        }
        return upstream
    }

    // MARK: - Response delivery

    private func deliver(_ response: HTTPURLResponse, body: Data,
                         request: HTTPRequest, upstream: URL) async {
        var body = body
        let contentType = (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if Self.rewritableContentTypes.contains(where: { contentType.hasPrefix($0) }) {
            body = rewriteSchemes(in: body)
        }

        let reason = Self.reasonPhrases[response.statusCode] ?? "OK"
        var head = "HTTP/1.0 \(response.statusCode) \(reason)\r\n"
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String, let value = value as? String else { continue }
            let lower = name.lowercased()
            guard !Self.droppedResponseHeaders.contains(lower) else { continue }
            var outValue = value
            if lower == "location" || lower == "refresh" || lower == "content-location" {
                outValue = outValue.replacingOccurrences(of: "https://", with: "http://")
            }
            head += "\(name): \(sanitized(outValue))\r\n"
        }
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"

        var out = Data(head.utf8)
        if request.method.uppercased() != "HEAD" {
            out.append(body)
        }
        try? await send(out)

        log(LogEntry(method: request.method, url: request.target,
                     status: response.statusCode, bytes: body.count,
                     note: upstream.scheme == "https" ? "https → http" : "http"))
    }

    /// Replaces every `https://` with `http://` in textual bodies so that
    /// links, redirects and stylesheets keep flowing through the proxy.
    private func rewriteSchemes(in data: Data) -> Data {
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

    /// Header values must never contain CR/LF (response splitting).
    private func sanitized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Minimal HTML 3.2 error page, plain ASCII so any vintage browser can show it.
    private func sendSimplePage(status: Int, title: String, message: String) async {
        let html = """
        <html><head><title>\(title)</title></head>\
        <body><h1>\(title)</h1><p>\(message)</p>\
        <hr><p><i>RetroProxy</i></p></body></html>
        """
        let body = Data(html.utf8)
        let reason = Self.reasonPhrases[status] ?? "Error"
        let head = "HTTP/1.0 \(status) \(reason)\r\n"
            + "Content-Type: text/html\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(body)
        try? await send(out)
    }

    // MARK: - Raw socket I/O

    private func readRequest() async throws -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        var buffer = Data()
        var headerEnd: Range<Data.Index>?
        while headerEnd == nil {
            if buffer.count > 128 * 1024 { throw ProxyError.headersTooLarge }
            guard let chunk = try await receiveChunk() else {
                if buffer.isEmpty { return nil }
                throw ProxyError.unexpectedEOF
            }
            buffer.append(chunk)
            headerEnd = buffer.range(of: separator)
        }

        guard let head = String(data: Data(buffer[..<headerEnd!.lowerBound]), encoding: .isoLatin1)
        else { throw ProxyError.badRequest }
        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { throw ProxyError.badRequest }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { throw ProxyError.badRequest }

        var headers: [(name: String, value: String)] = []
        for line in lines.dropFirst() where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers.append((name, value))
        }

        var body = Data(buffer[headerEnd!.upperBound...])
        if let lengthValue = headers.first(where: { $0.name.lowercased() == "content-length" })?.value,
           let length = Int(lengthValue), length > 0 {
            guard length <= 32 * 1024 * 1024 else { throw ProxyError.bodyTooLarge }
            while body.count < length {
                guard let chunk = try await receiveChunk() else { throw ProxyError.unexpectedEOF }
                body.append(chunk)
            }
            body = body.prefix(length)
        } else {
            body = Data()
        }

        return HTTPRequest(method: parts[0], target: parts[1],
                           version: parts.count >= 3 ? parts[2] : "HTTP/1.0",
                           headers: headers, body: body)
    }

    private func receiveChunk() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
