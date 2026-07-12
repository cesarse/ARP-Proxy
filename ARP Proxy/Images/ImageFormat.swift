import Foundation

/// Image formats the proxy recognizes. Detection trusts magic bytes over
/// the Content-Type header, because CDNs occasionally mislabel images.
nonisolated enum ImageFormat: String, Sendable, CaseIterable {
    case webp, avif, heic, jpeg, png, gif

    static func detect(data: Data, contentType: String) -> ImageFormat? {
        let header = Data(data.prefix(12))
        if header.count >= 12 {
            if header[0..<4].elementsEqual("RIFF".utf8),
               header[8..<12].elementsEqual("WEBP".utf8) {
                return .webp
            }
            if header[4..<8].elementsEqual("ftyp".utf8) {
                let brand = String(decoding: header[8..<12], as: UTF8.self)
                if brand.hasPrefix("av") { return .avif }
                if ["heic", "heix", "hevc", "hevx", "mif1", "msf1"].contains(brand) {
                    return .heic
                }
            }
        }
        if header.count >= 8,
           header[0..<8].elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return .png
        }
        if header.count >= 4, header[0..<4].elementsEqual("GIF8".utf8) {
            return .gif
        }
        if header.count >= 3, header[0] == 0xFF, header[1] == 0xD8, header[2] == 0xFF {
            return .jpeg
        }
        let base = contentType.split(separator: ";").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        switch base {
        case "image/webp": return .webp
        case "image/avif": return .avif
        case "image/heic", "image/heif": return .heic
        case "image/jpeg", "image/jpg", "image/pjpeg": return .jpeg
        case "image/png", "image/x-png": return .png
        case "image/gif": return .gif
        default: return nil
        }
    }
}
