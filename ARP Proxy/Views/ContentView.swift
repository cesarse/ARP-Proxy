import SwiftUI

struct ContentView: View {
    var server: ProxyServer
    @State private var interfaces: [NetworkInterfaceAddress] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if server.isRunning {
                AddressesPanel(interfaces: interfaces, port: server.settings.port)
            }
            Divider()
            logHeader
            RequestLogView(entries: server.entries)
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

    private var header: some View {
        HStack {
            StatusView(state: server.state, port: server.settings.port)
            if server.settings.waybackEnabled {
                WaybackBadge(date: server.settings.waybackDate)
                    .padding(.leading, 8)
            }
            Spacer()
            Button {
                server.toggle()
            } label: {
                server.isRunning ? Text("Stop Proxy") : Text("Start Proxy")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var logHeader: some View {
        HStack {
            Text("Requests").font(.headline)
            Spacer()
            Button("Clear") { server.clearLog() }
                .disabled(server.entries.isEmpty)
        }
    }
}

#Preview {
    ContentView(server: ProxyServer())
}
