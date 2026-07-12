import Foundation
import SwiftSoup

/// <noscript> content is exactly what a JS-less browser should see.
/// Runs before the tag sweep so anything it spills out (fallback
/// stylesheets etc.) still gets removed.
nonisolated struct UnwrapNoscriptPass: HTMLPass {
    func run(on doc: Document) throws {
        try doc.select("noscript").unwrap()
    }
}
