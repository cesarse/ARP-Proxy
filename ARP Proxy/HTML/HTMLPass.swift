import Foundation
import SwiftSoup

/// One self-contained transformation over the parsed document.
nonisolated protocol HTMLPass: Sendable {
    func run(on doc: Document) throws
}
