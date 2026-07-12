import Foundation

/// The HTML dialect the proxy targets for vintage browsers.
nonisolated enum HTMLVersion: String, Sendable, CaseIterable {
    case html32
    case html401
}
