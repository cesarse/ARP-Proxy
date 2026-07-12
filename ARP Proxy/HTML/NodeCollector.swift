import Foundation
import SwiftSoup

/// Depth-first collector for nodes of one type, since SwiftSoup has no
/// typed query for non-element nodes (comments, doctypes).
nonisolated enum NodeCollector {
    static func nodes<NodeType: Node>(ofType type: NodeType.Type, in root: Node) -> [NodeType] {
        var found: [NodeType] = []
        walk(root) { node in
            if let match = node as? NodeType { found.append(match) }
        }
        return found
    }

    private static func walk(_ node: Node, _ visit: (Node) -> Void) {
        visit(node)
        for child in node.getChildNodes() {
            walk(child, visit)
        }
    }
}
