import Foundation

/// Lifecycle of the listening proxy, shown in the main window.
nonisolated enum ProxyServerState: Equatable, Sendable {
    case stopped
    case running
    case failed(String)
}
