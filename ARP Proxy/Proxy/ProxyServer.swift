import Foundation
import Network
import Observation

@Observable
final class ProxyServer {
    private(set) var state: ProxyServerState = .stopped
    private(set) var entries: [LogEntry] = []

    var settings: ProxySettings = ProxySettings.load() {
        didSet {
            let clamped = settings.clamped()
            if clamped != settings {
                settings = clamped  // re-enters didSet once, with a stable value
                return
            }
            guard settings != oldValue else { return }
            settings.save()
            if settings.port != oldValue.port, listener != nil {
                stop()
                start()
            }
        }
    }

    var isRunning: Bool { state == .running }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ARP Proxy.listener")

    func start() {
        guard listener == nil else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: settings.port)),
              port.rawValue > 0 else {
            state = .failed("Invalid port")
            return
        }
        do {
            // Allow rebinding a socket still lingering in TIME_WAIT so a quick
            // stop/start (or a crash) doesn't fail with "Address already in use".
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: port)
            listener.stateUpdateHandler = { [weak self] newState in
                Task { @MainActor in self?.listenerChanged(to: newState) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                let handler = ProxyConnection(connection: connection) { entry in
                    Task { @MainActor in self?.append(entry) }
                }
                Task.detached { await handler.run() }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        state = .stopped
    }

    func toggle() {
        if listener == nil { start() } else { stop() }
    }

    func clearLog() {
        entries.removeAll()
    }

    private func listenerChanged(to newState: NWListener.State) {
        switch newState {
        case .ready:
            state = .running
        case .failed(let error):
            state = .failed(error.localizedDescription)
            listener?.cancel()
            listener = nil
        case .cancelled:
            if state == .running { state = .stopped }
        default:
            break
        }
    }

    private func append(_ entry: LogEntry) {
        entries.append(entry)
        // Keep the log bounded so long sessions don't grow without limit.
        if entries.count > 500 {
            entries.removeFirst(entries.count - 500)
        }
    }
}
