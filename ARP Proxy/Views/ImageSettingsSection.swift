import SwiftUI

struct ImageSettingsSection: View {
    @Bindable var server: ProxyServer

    var body: some View {
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
    }
}
