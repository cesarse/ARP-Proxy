import Foundation
import SystemConfiguration

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

nonisolated enum NetworkInfo {
    /// IPv4 addresses of the Mac's active non-loopback interfaces, each tagged
    /// with the interface it belongs to, so the user can pick the one their
    /// guest OS can actually reach.
    static func ipv4Interfaces() -> [NetworkInterfaceAddress] {
        let friendly = friendlyNames()
        var result: [NetworkInterfaceAddress] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return [] }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let address = pointer.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET)
            else { continue }

            let bsdName = String(cString: pointer.pointee.ifa_name)

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len),
                              &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let ip = host.withUnsafeBufferPointer {
                String(decoding: $0.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                       as: UTF8.self)
            }
            guard !ip.isEmpty else { continue }

            let entry = NetworkInterfaceAddress(
                bsdName: bsdName,
                displayName: displayName(for: bsdName, friendly: friendly),
                address: ip)
            if !result.contains(entry) {
                result.append(entry)
            }
        }
        return result
    }

    /// Map of BSD name → system-provided localized name ("Wi-Fi", "Ethernet",
    /// "Thunderbolt Bridge", …) for the interfaces macOS knows about.
    private static func friendlyNames() -> [String: String] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        var map: [String: String] = [:]
        for interface in interfaces {
            if let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
               let name = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? {
                map[bsd] = name
            }
        }
        return map
    }

    /// Prefer the system's name; otherwise recognise the interfaces UTM/QEMU
    /// and VPNs create, which macOS doesn't list in its network preferences.
    private static func displayName(for bsdName: String, friendly: [String: String]) -> String {
        if let name = friendly[bsdName] { return name }
        if bsdName.hasPrefix("bridge") { return String(localized: "UTM shared network") }
        if bsdName.hasPrefix("utun") || bsdName.hasPrefix("ipsec") || bsdName.hasPrefix("ppp") {
            return String(localized: "VPN")
        }
        return ""
    }
}
