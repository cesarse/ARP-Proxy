import Foundation

/// Strategy: each target HTML dialect contributes its DOCTYPE and any
/// version-specific passes; `HTMLSimplificationEngine` does the rest.
nonisolated protocol HTMLSimplifying: Sendable {
    var doctype: DoctypeDeclaration { get }
    /// Extra passes for this dialect, run after the common passes and
    /// before attribute pruning.
    var versionPasses: [any HTMLPass] { get }
}
