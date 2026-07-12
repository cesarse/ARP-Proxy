import Foundation
import Network
import Observation

nonisolated struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let date = Date()
    var method: String
    var url: String
    var status: Int?
    var bytes: Int?
    var note: String?
}

@Observable
final class ProxyServer {
    enum State: Equatable {
        case stopped
        case running
        case failed(String)
    }

    private(set) var state: State = .stopped
    private(set) var entries: [LogEntry] = []
    var port: Int = 8080

    var isRunning: Bool { state == .running }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "RetroProxy.listener")

    func start() {
        guard listener == nil else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: port)), port.rawValue > 0 else {
            state = .failed("Invalid port")
            return
        }
        do {
            let listener = try NWListener(using: .tcp, on: port)
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
