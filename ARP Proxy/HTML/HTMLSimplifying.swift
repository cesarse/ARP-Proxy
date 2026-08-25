import Foundation

/// Strategy: each target HTML dialect contributes its DOCTYPE and any
/// version-specific passes; `HTMLSimplificationEngine` does the rest.
nonisolated protocol HTMLSimplifying: Sendable {
    var doctype: DoctypeDeclaration { get }
    /// The element names this dialect defines. Anything else is unwrapped,
    /// so the DOCTYPE above stays a true statement about the document.
    var vocabulary: Set<String> { get }
    /// Extra passes for this dialect, run after the common passes and
    /// before attribute pruning.
    var versionPasses: [any HTMLPass] { get }
}
