import Foundation

nonisolated enum NetworkInfo {
    /// IPv4 addresses of the Mac's active non-loopback interfaces, so the user
    /// can point the guest OS at one of them.
    static func ipv4Addresses() -> [String] {
        var addresses: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return [] }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let address = pointer.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len),
                           &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let name = host.withUnsafeBufferPointer {
                    String(decoding: $0.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
                           as: UTF8.self)
                }
                if !name.isEmpty, !addresses.contains(name) {
                    addresses.append(name)
                }
            }
        }
        return addresses
    }
}
