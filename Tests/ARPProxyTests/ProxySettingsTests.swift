import Foundation
import Testing
@testable import ARPProxyHTML

@Suite("Proxy settings")
struct ProxySettingsTests {

    /// Runs `body` against a throwaway defaults domain, never the user's.
    private func withScratchDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "ARPProxyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test("Defaults match what a first launch should get")
    func defaults() {
        let settings = ProxySettings()
        #expect(settings.port == 8080)
        #expect(settings.convertImages)
        #expect(settings.jpegQuality == 0.8)
        #expect(settings.maxImageDimension == 2048)
        #expect(settings.simplifyHTML)
        #expect(settings.htmlVersion == .html32)
        #expect(settings.stripImageDimensions)
        #expect(!settings.reproduceLayout)
    }

    @Test("Loading from an empty store yields the defaults")
    func loadsDefaultsFromEmptyStore() {
        withScratchDefaults { defaults in
            #expect(ProxySettings.load(from: defaults) == ProxySettings())
        }
    }

    @Test("Every setting survives a save and load")
    func roundTrips() {
        withScratchDefaults { defaults in
            var settings = ProxySettings()
            settings.port = 3128
            settings.convertImages = false
            settings.jpegQuality = 0.55
            settings.maxImageDimension = 1024
            settings.simplifyHTML = false
            settings.htmlVersion = .html401
            settings.stripImageDimensions = false
            settings.reproduceLayout = true
            settings.save(to: defaults)
            #expect(ProxySettings.load(from: defaults) == settings)
        }
    }

    @Test("Out-of-range persisted values are clamped on load")
    func clampsOnLoad() {
        withScratchDefaults { defaults in
            defaults.set(70_000, forKey: "port")
            defaults.set(0.1, forKey: "jpegQuality")
            defaults.set(100, forKey: "maxImageDimension")
            let settings = ProxySettings.load(from: defaults)
            #expect(settings.port == 65535)
            #expect(settings.jpegQuality == 0.3)
            #expect(settings.maxImageDimension == 320)
        }
    }

    @Test("Clamping pins each value to its range")
    func clamping() {
        var low = ProxySettings()
        low.port = 0
        low.jpegQuality = 0
        low.maxImageDimension = 0
        #expect(low.clamped().port == 1)
        #expect(low.clamped().jpegQuality == 0.3)
        #expect(low.clamped().maxImageDimension == 320)

        var high = ProxySettings()
        high.port = 100_000
        high.jpegQuality = 2
        high.maxImageDimension = 100_000
        #expect(high.clamped().port == 65535)
        #expect(high.clamped().jpegQuality == 1.0)
        #expect(high.clamped().maxImageDimension == 8192)
    }

    @Test("In-range values are untouched by clamping")
    func clampingIsIdentityInRange() {
        #expect(ProxySettings().clamped() == ProxySettings())
    }

    @Test("An unknown HTML version falls back to the default")
    func unknownHTMLVersion() {
        withScratchDefaults { defaults in
            defaults.set("html5", forKey: "htmlVersion")
            #expect(ProxySettings.load(from: defaults).htmlVersion == .html32)
        }
    }
}
