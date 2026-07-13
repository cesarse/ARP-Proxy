import SwiftUI

/// Colored dot plus one line describing the proxy's lifecycle state.
struct StatusView: View {
    let state: ProxyServerState
    let port: Int

    var body: some View {
        switch state {
        case .running:
            Label {
                Text("Running on port \(port, format: .number.grouping(.never))")
            } icon: {
                Circle().fill(.green).frame(width: 10, height: 10)
            }
        case .stopped:
            Label {
                Text("Stopped").foregroundStyle(.secondary)
            } icon: {
                Circle().fill(.gray).frame(width: 10, height: 10)
            }
        case .failed(let message):
            Label {
                Text("Error: \(message)").foregroundStyle(.red)
            } icon: {
                Circle().fill(.red).frame(width: 10, height: 10)
            }
        }
    }
}
