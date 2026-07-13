import SwiftUI

/// Liquid Glass panel listing the proxy addresses a guest OS can use.
struct AddressesPanel: View {
    let interfaces: [NetworkInterfaceAddress]
    let port: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set your vintage browser's HTTP proxy to one of these addresses:")
            ForEach(interfaces) { iface in
                HStack(spacing: 8) {
                    Text(verbatim: "\(iface.address):\(port)")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Text(verbatim: iface.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Text("From a UTM guest on the emulated network, use \("10.0.2.2:\(port)").")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
