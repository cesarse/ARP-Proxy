import Foundation

/// Factory: maps the user's setting to the matching dialect strategy.
nonisolated enum HTMLSimplifierFactory {
    static func simplifier(for version: HTMLVersion) -> any HTMLSimplifying {
        switch version {
        case .html32: HTML32Simplifier()
        case .html401: HTML401Simplifier()
        }
    }
}
