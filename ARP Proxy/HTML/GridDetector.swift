import Foundation
import SwiftSoup

/// Finds the card grids on a page.
///
/// Modern pages keep their layout in CSS, which is gone by the time we look,
/// so the grid has to be inferred from the markup alone. What survives is
/// repetition: a grid is a run of siblings with the same tag and class, each
/// about the same size, each carrying an image.
///
/// The thresholds below come from measuring the benchmark corpus. On CNN the
/// separation is stark — content cards carry an image in every member and run
/// ~26 nodes each, while the navigation menus that repeat just as often carry
/// no image at all and run 1–2 nodes. The upper size bound matters too: CNN's
/// eight `div.zone` sections repeat and contain images, but at ~150 nodes they
/// are full-width page sections, and standing them side by side would be
/// nonsense.
nonisolated struct GridDetector {
    /// Fewer than this is a pair of related boxes, not a grid.
    private static let minimumMembers = 3
    /// A cell smaller than this is a link in a list; larger is a page section.
    private static let memberNodeRange = 5...80
    /// Allows one card in a group to be text-only without losing the grid.
    private static let minimumImageShare = 0.8
    /// A page laying itself out as a grid does so more than once. A single
    /// repeated run is a list — DuckDuckGo's ten search results are exactly
    /// that, and they read far better left alone than stood in columns.
    private static let minimumGridsPerPage = 2

    func candidates(in doc: Document) throws -> [GridCandidate] {
        var found: [GridCandidate] = []
        for parent in try doc.getAllElements().array() where !Self.isNavigational(parent) {
            let children = parent.children().array()
            guard children.count >= Self.minimumMembers else { continue }

            var groups: [String: [Element]] = [:]
            for child in children {
                groups[Self.signature(of: child), default: []].append(child)
            }
            for members in groups.values
            where members.count >= Self.minimumMembers && Self.qualifies(members) {
                found.append(GridCandidate(parent: parent, members: members))
            }
        }
        let outermost = found.filter { candidate in
            !found.contains { $0.contains(candidate) }
        }
        return outermost.count >= Self.minimumGridsPerPage ? outermost : []
    }

    // MARK: - Tests a run has to pass

    private static func qualifies(_ members: [Element]) -> Bool {
        let withImages = members.filter { element in
            (try? element.select("img").isEmpty() == false) ?? false
        }.count
        guard Double(withImages) / Double(members.count) >= minimumImageShare else {
            return false
        }
        let sizes = members.map { nodeCount(of: $0) }.sorted()
        return memberNodeRange.contains(sizes[sizes.count / 2])
    }

    /// The class a site names its repeated block with — `card`,
    /// `container__item`, `GridItem-styled…`. BEM-ish names carry the
    /// structure, so they identify siblings that belong together far more
    /// reliably than the tag alone.
    private static func signature(of element: Element) -> String {
        let classes = (try? element.attr("class"))?
            .split(separator: " ").map(String.init) ?? []
        let primary = classes.first { $0.contains("__") || $0.contains("-") }
            ?? classes.first
            ?? ""
        return "\(element.tagName())|\(primary)"
    }

    private static func nodeCount(of element: Element) -> Int {
        1 + element.children().reduce(0) { $0 + nodeCount(of: $1) }
    }

    /// Menus and footers repeat as regularly as any grid; they are lists of
    /// links and belong in a column, not a table.
    private static func isNavigational(_ element: Element) -> Bool {
        var current: Element? = element
        while let node = current {
            if ["nav", "header", "footer"].contains(node.tagName()) { return true }
            current = node.parent()
        }
        return false
    }
}
