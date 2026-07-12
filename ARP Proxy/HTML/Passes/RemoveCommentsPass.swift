import Foundation
import SwiftSoup

/// Comments are dead weight on a 33.6 kbps modem.
nonisolated struct RemoveCommentsPass: HTMLPass {
    func run(on doc: Document) throws {
        for comment in NodeCollector.nodes(ofType: Comment.self, in: doc) {
            try comment.remove()
        }
    }
}
