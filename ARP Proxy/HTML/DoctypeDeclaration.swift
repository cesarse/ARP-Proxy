import Foundation
import SwiftSoup

/// The identity of an HTML dialect's DOCTYPE, kept as plain data so a
/// fresh SwiftSoup node can be minted for every document (a node belongs
/// to one document at a time).
nonisolated struct DoctypeDeclaration: Sendable {
    let publicId: String
    let systemId: String

    func makeNode() -> DocumentType {
        DocumentType("html", publicId, systemId, "")
    }
}
