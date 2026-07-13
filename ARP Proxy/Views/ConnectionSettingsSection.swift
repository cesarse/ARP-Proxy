import SwiftUI

struct ConnectionSettingsSection: View {
    @Bindable var server: ProxyServer

    var body: some View {
        Section {
            TextField("Port:", value: $server.settings.port,
                      format: .number.grouping(.never))
            Text("Changing the port restarts the proxy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Connection")
        }
    }
}
