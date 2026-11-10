import Foundation
import SwiftSoup

/// A run of sibling elements that look like cells of one grid: same tag, same
/// primary class, comparable size, each carrying an image.
nonisolated struct GridCandidate {
    let parent: Element
    let members: [Element]

    /// True when `other` sits inside one of our members, so only the
    /// outermost of a nested pair gets turned into a table.
    func contains(_ other: GridCandidate) -> Bool {
        members.contains { member in
            var ancestor: Element? = other.parent
            while let current = ancestor {
                if current === member { return true }
                ancestor = current.parent()
            }
            return false
        }
    }
}
