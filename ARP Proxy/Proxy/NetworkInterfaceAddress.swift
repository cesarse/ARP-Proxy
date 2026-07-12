import Foundation

/// An IPv4 address bound to a named network interface, ready to show the user.
nonisolated struct NetworkInterfaceAddress: Identifiable, Sendable, Hashable {
    var id: String { bsdName + "/" + address }
    /// BSD interface name, e.g. "en0", "bridge100".
    let bsdName: String
    /// Human-friendly interface name, e.g. "Wi-Fi", "UTM shared network".
    /// Empty when we have nothing better than the BSD name.
    let displayName: String
    /// Dotted-quad IPv4 address, e.g. "192.168.1.23".
    let address: String

    /// "en0 — Wi-Fi" style label; just "en0" when no friendly name is known.
    var label: String {
        displayName.isEmpty ? bsdName : "\(bsdName) — \(displayName)"
    }
}
