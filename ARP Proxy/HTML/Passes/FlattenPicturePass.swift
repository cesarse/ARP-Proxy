import Foundation
import SwiftSoup

/// Reduces <picture> to the plain <img> inside it; the <source> variants
/// only mean something to browsers that negotiate formats.
nonisolated struct FlattenPicturePass: HTMLPass {
    func run(on doc: Document) throws {
        try doc.select("picture > source").remove()
        try doc.select("picture").unwrap()
    }
}
