import SwiftUI

struct SettingsView: View {
    @Bindable var server: ProxyServer

    var body: some View {
        Form {
            ConnectionSettingsSection(server: server)
            ImageSettingsSection(server: server)
            HTMLSettingsSection(server: server)
            WaybackSettingsSection(server: server)
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }
}

#Preview {
    SettingsView(server: ProxyServer())
}
