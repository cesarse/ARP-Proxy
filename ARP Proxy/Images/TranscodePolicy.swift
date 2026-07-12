import Foundation

/// Hard limits shared by all transcoding strategies.
nonisolated enum TranscodePolicy {
    /// Bodies larger than this are passed through untouched.
    static let maxInputBytes = 24 * 1024 * 1024
    /// Animations with more frames than this are reduced to their first frame.
    static let maxAnimationFrames = 200
}
