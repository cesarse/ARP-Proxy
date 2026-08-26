import SwiftUI

struct HTMLSettingsSection: View {
    @Bindable var server: ProxyServer

    var body: some View {
        Section {
            Toggle("Simplify HTML for vintage browsers",
                   isOn: $server.settings.simplifyHTML)
            Picker("HTML version", selection: $server.settings.htmlVersion) {
                Text(verbatim: "HTML 3.2").tag(HTMLVersion.html32)
                Text(verbatim: "HTML 4.01").tag(HTMLVersion.html401)
            }
            .pickerStyle(.segmented)
            .disabled(!server.settings.simplifyHTML)
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Reproduce page layout with tables",
                       isOn: $server.settings.reproduceLayout)
                Text("Rebuilds column layouts with tables, the way pages were built before CSS. The original structure has to be guessed at, so some pages read better with this off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(!server.settings.simplifyHTML)
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Remove image size attributes",
                       isOn: $server.settings.stripImageDimensions)
                Text("Fixes stretched images on sites that size them with CSS, at the cost of some reflow while a page loads.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(!server.settings.simplifyHTML)
        } header: {
            Text("HTML")
        }
    }
}
