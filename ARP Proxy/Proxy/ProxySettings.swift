import Foundation

/// User-configurable proxy behavior, persisted in UserDefaults. Connections
/// load a snapshot per request, so changes apply without a restart (except
/// the port, which requires rebinding the listener).
nonisolated struct ProxySettings: Sendable, Equatable {

    var port: Int = 8080
    var convertImages: Bool = true
    var jpegQuality: Double = 0.8
    var maxImageDimension: Int = 2048
    var simplifyHTML: Bool = true
    var htmlVersion: HTMLVersion = .html32
    /// Modern sites size images with CSS, so width/height attributes often
    /// disagree with the served file and stretch it in a CSS-less browser.
    /// Stripping them trades stable layout during load for correct rendering.
    var stripImageDimensions: Bool = true
    /// Modern pages keep their layout entirely in CSS, which the simplifier
    /// strips — so a simplified page arrives as one long column. Rebuilding
    /// the columns as tables is the period-accurate substitute, but the
    /// original structure has to be inferred from the markup, and a wrong
    /// guess reads worse than no layout at all. Hence opt-in.
    var reproduceLayout: Bool = false

    private enum Keys {
        static let port = "port"
        static let convertImages = "convertImages"
        static let jpegQuality = "jpegQuality"
        static let maxImageDimension = "maxImageDimension"
        static let simplifyHTML = "simplifyHTML"
        static let htmlVersion = "htmlVersion"
        static let stripImageDimensions = "stripImageDimensions"
        static let reproduceLayout = "reproduceLayout"
    }

    static func load(from defaults: UserDefaults = .standard) -> ProxySettings {
        var settings = ProxySettings()
        if defaults.object(forKey: Keys.port) != nil {
            settings.port = defaults.integer(forKey: Keys.port)
        }
        if defaults.object(forKey: Keys.convertImages) != nil {
            settings.convertImages = defaults.bool(forKey: Keys.convertImages)
        }
        if defaults.object(forKey: Keys.jpegQuality) != nil {
            settings.jpegQuality = defaults.double(forKey: Keys.jpegQuality)
        }
        if defaults.object(forKey: Keys.maxImageDimension) != nil {
            settings.maxImageDimension = defaults.integer(forKey: Keys.maxImageDimension)
        }
        if defaults.object(forKey: Keys.simplifyHTML) != nil {
            settings.simplifyHTML = defaults.bool(forKey: Keys.simplifyHTML)
        }
        if let raw = defaults.string(forKey: Keys.htmlVersion),
           let version = HTMLVersion(rawValue: raw) {
            settings.htmlVersion = version
        }
        if defaults.object(forKey: Keys.stripImageDimensions) != nil {
            settings.stripImageDimensions = defaults.bool(forKey: Keys.stripImageDimensions)
        }
        if defaults.object(forKey: Keys.reproduceLayout) != nil {
            settings.reproduceLayout = defaults.bool(forKey: Keys.reproduceLayout)
        }
        return settings.clamped()
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(port, forKey: Keys.port)
        defaults.set(convertImages, forKey: Keys.convertImages)
        defaults.set(jpegQuality, forKey: Keys.jpegQuality)
        defaults.set(maxImageDimension, forKey: Keys.maxImageDimension)
        defaults.set(simplifyHTML, forKey: Keys.simplifyHTML)
        defaults.set(htmlVersion.rawValue, forKey: Keys.htmlVersion)
        defaults.set(stripImageDimensions, forKey: Keys.stripImageDimensions)
        defaults.set(reproduceLayout, forKey: Keys.reproduceLayout)
    }

    func clamped() -> ProxySettings {
        var settings = self
        settings.port = min(max(settings.port, 1), 65535)
        settings.jpegQuality = min(max(settings.jpegQuality, 0.3), 1.0)
        settings.maxImageDimension = min(max(settings.maxImageDimension, 320), 8192)
        return settings
    }
}
