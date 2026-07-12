import SwiftUI

struct SettingsView: View {
    @Bindable var server: ProxyServer

    var body: some View {
        Form {
            Section {
                TextField("Port:", value: $server.settings.port,
                          format: .number.grouping(.never))
                Text("Changing the port restarts the proxy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Connection")
            }

            Section {
                Toggle("Convert modern images (WebP, AVIF, HEIC)",
                       isOn: $server.settings.convertImages)
                LabeledContent("JPEG quality") {
                    HStack(spacing: 8) {
                        Slider(value: $server.settings.jpegQuality, in: 0.3...1.0, step: 0.05)
                        Text(verbatim: "\(Int((server.settings.jpegQuality * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .disabled(!server.settings.convertImages)
                Picker("Maximum image size", selection: $server.settings.maxImageDimension) {
                    ForEach([640, 800, 1024, 1280, 1600, 2048, 4096], id: \.self) { size in
                        Text(verbatim: "\(size) px").tag(size)
                    }
                }
                .disabled(!server.settings.convertImages)
            } header: {
                Text("Images")
            }

            Section {
                Toggle("Simplify HTML for vintage browsers",
                       isOn: $server.settings.simplifyHTML)
                Picker("HTML version", selection: $server.settings.htmlVersion) {
                    Text(verbatim: "HTML 3.2").tag(ProxySettings.HTMLVersion.html32)
                    Text(verbatim: "HTML 4.01").tag(ProxySettings.HTMLVersion.html401)
                }
                .pickerStyle(.segmented)
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
        .formStyle(.grouped)
        .frame(width: 440)
    }
}

#Preview {
    SettingsView(server: ProxyServer())
}
