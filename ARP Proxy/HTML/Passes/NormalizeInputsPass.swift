import Foundation
import SwiftSoup

/// Input types newer than HTML 4 become plain text fields; unknown types
/// default to text anyway, but being explicit avoids surprises in the
/// strangest old browsers.
nonisolated struct NormalizeInputsPass: HTMLPass {
    private static let modernInputTypes: Set<String> = [
        "email", "url", "tel", "search", "number", "date", "time",
        "datetime-local", "month", "week", "color", "range",
    ]

    func run(on doc: Document) throws {
        for input in try doc.select("input").array()
        where Self.modernInputTypes.contains(try input.attr("type").lowercased()) {
            try input.attr("type", "text")
        }
    }
}
