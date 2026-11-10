import Foundation
import Network

/// Orchestrates one accepted browser connection: read the request, fetch
/// it from the modern web (HTTPS first), downgrade the response, and write
/// it back as HTTP/1.0. The heavy lifting lives in small collaborators.
nonisolated final class ProxyConnection: @unchecked Sendable {

    private let socket: BrowserSocket
    private let log: @Sendable (LogEntry) -> Void

    init(connection: NWConnection, log: @escaping @Sendable (LogEntry) -> Void) {
        self.socket = BrowserSocket(connection)
        self.log = log
    }

    func run() async {
        socket.open()
        // Snapshot per connection: settings changes apply to the next request
        // without restarting the proxy.
        let settings = ProxySettings.load()
        do {
            if let request = try await HTTPRequestReader(socket: socket).read() {
                await handle(request, settings: settings)
            }
        } catch {
            await respond(with: ErrorPage(status: 400, title: "Bad Request",
                                          message: "ARP Proxy could not parse the request."))
        }
        socket.close()
    }

    private func handle(_ request: HTTPRequest, settings: ProxySettings) async {
        if request.method.uppercased() == "CONNECT" {
            await rejectTunneling(request)
            return
        }
        guard let url = UpstreamURLResolver.url(for: request) else {
            await rejectUnparseableTarget(request)
            return
        }
        if settings.waybackEnabled, !WaybackSnapshot.isArchive(url) {
            await handleFromArchive(request, url: url, settings: settings)
            return
        }
        do {
            let candidates = HTTPSUpgrader.candidates(for: url)
            let upstream = try await UpstreamFetcher.fetch(request, trying: candidates)
            await deliver(upstream, request: request, settings: settings)
        } catch {
            await reportGatewayFailure(request, url: url, error: error)
        }
    }

    /// Wayback mode: the same URL, as the Internet Archive captured it near
    /// the chosen date. The browser is never told; it sees the original
    /// addresses, and every link it follows comes back here.
    private func handleFromArchive(_ request: HTTPRequest, url: URL,
                                   settings: ProxySettings) async {
        guard ["GET", "HEAD"].contains(request.method.uppercased()) else {
            await rejectArchiveSubmission(request)
            return
        }
        let timestamp = WaybackSnapshot.timestamp(for: settings.waybackDate)
        do {
            let upstream = try await WaybackFetcher.fetch(request, original: url,
                                                          timestamp: timestamp)
            await deliver(upstream, request: request, settings: settings)
        } catch let error as WaybackError {
            let page = error.errorPage(for: url, near: settings.waybackDate)
            await respond(with: page)
            log(LogEntry(method: request.method, url: request.target,
                         status: page.status, note: error.logNote))
        } catch {
            await reportGatewayFailure(request, url: WaybackSnapshot.archiveRoot, error: error)
        }
    }

    private func deliver(_ upstream: UpstreamResponse, request: HTTPRequest,
                         settings: ProxySettings) async {
        let transformed = BodyTransformer(settings: settings)
            .transform(upstream.body, contentType: upstream.contentType)
        let head = ResponseHeadBuilder.build(for: upstream.response,
                                             bodyLength: transformed.data.count,
                                             contentTypeOverride: transformed.contentTypeOverride)
        var out = Data(head.utf8)
        if request.method.uppercased() != "HEAD" {
            out.append(transformed.data)
        }
        try? await socket.send(out)
        log(LogEntry(method: request.method, url: request.target,
                     status: upstream.response.statusCode, bytes: transformed.data.count,
                     note: deliveryNote(for: upstream, transformNote: transformed.note)))
    }

    private func deliveryNote(for upstream: UpstreamResponse, transformNote: String?) -> String {
        var note = upstream.archivedAt.map { "wayback " + WaybackSnapshot.day(ofTimestamp: $0) }
            ?? (upstream.usedHTTPS ? "https → http" : "http")
        if let transformNote {
            note += ", " + transformNote
        }
        return note
    }

    private func rejectTunneling(_ request: HTTPRequest) async {
        await respond(with: ErrorPage(
            status: 501, title: "HTTPS Tunneling Not Supported",
            message: "Request the page with http:// instead of https://. "
                + "ARP Proxy upgrades the connection to HTTPS for you."))
        log(LogEntry(method: request.method, url: request.target,
                     status: 501, note: "CONNECT rejected"))
    }

    private func rejectArchiveSubmission(_ request: HTTPRequest) async {
        await respond(with: ErrorPage(
            status: 501, title: "Forms Cannot Be Sent to the Past",
            message: "The Wayback Machine replays pages it archived; it cannot submit forms. "
                + "Turn off Wayback mode in ARP Proxy to use this form."))
        log(LogEntry(method: request.method, url: request.target,
                     status: 501, note: "wayback: \(request.method) not replayable"))
    }

    private func rejectUnparseableTarget(_ request: HTTPRequest) async {
        await respond(with: ErrorPage(status: 400, title: "Bad Request",
                                      message: "The request target could not be understood."))
        log(LogEntry(method: request.method, url: request.target,
                     status: 400, note: "unparseable target"))
    }

    private func reportGatewayFailure(_ request: HTTPRequest, url: URL, error: Error) async {
        let message = error.localizedDescription
        await respond(with: ErrorPage(
            status: 502, title: "Bad Gateway",
            message: "Could not reach \(url.host ?? "the server"): \(message)"))
        log(LogEntry(method: request.method, url: request.target,
                     status: 502, note: message))
    }

    private func respond(with page: ErrorPage) async {
        try? await socket.send(page.encodedResponse())
    }
}
