import Foundation

/// Facade: assembles the engine for the configured dialect and runs it.
/// Kept so callers don't care about the strategy machinery.
nonisolated enum HTMLSimplifier {
    static func simplify(_ data: Data, contentType: String,
                         settings: ProxySettings) -> Data? {
        let dialect = HTMLSimplifierFactory.simplifier(for: settings.htmlVersion)
        return HTMLSimplificationEngine(dialect: dialect, settings: settings)
            .simplify(data, contentType: contentType)
    }
}
