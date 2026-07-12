import SwiftUI

struct ContentView: View {
    @Bindable var server: ProxyServer
    @State private var interfaces: [NetworkInterfaceAddress] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusView
                Spacer()
                Button {
                    server.toggle()
                } label: {
                    server.isRunning ? Text("Stop Proxy") : Text("Start Proxy")
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }

            if server.isRunning {
                addressesBox
            }

            Divider()

            HStack {
                Text("Requests").font(.headline)
                Spacer()
                Button("Clear") { server.clearLog() }
                    .disabled(server.entries.isEmpty)
            }

            logView
        }
        .padding()
        .frame(minWidth: 660, minHeight: 460)
        .task {
            interfaces = NetworkInfo.ipv4Interfaces()
            // Xcode's Canvas renders the view in a separate, long-lived process.
            // If it bound the port, it would hold it and the real app run would
            // fail with "port already in use", so skip the listener in previews.
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                server.start()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch server.state {
        case .running:
            Label {
                Text("Running on port \(server.settings.port, format: .number.grouping(.never))")
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

    private var addressesBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set your vintage browser's HTTP proxy to one of these addresses:")
            ForEach(interfaces) { iface in
                HStack(spacing: 8) {
                    Text(verbatim: "\(iface.address):\(server.settings.port)")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Text(verbatim: iface.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text("From a UTM guest on the emulated network, use \("10.0.2.2:\(server.settings.port)").")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var logView: some View {
        if server.entries.isEmpty {
            Text("No requests yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(server.entries.reversed()) { entry in
                        LogRow(entry: entry)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView(server: ProxyServer())
}
