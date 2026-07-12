import Foundation
import SwiftSoup

/// <button> arrived with HTML 4; Netscape 3/4 can't submit with it.
/// Inside a form it becomes <input type=submit>; elsewhere it could only
/// ever have triggered JavaScript, so it goes away.
nonisolated struct ConvertButtonsPass: HTMLPass {
    func run(on doc: Document) throws {
        for button in try doc.select("button").array() {
            try process(button)
        }
    }

    private func process(_ button: Element) throws {
        let type = try button.attr("type").lowercased()
        if isInsideForm(button), type != "button" {
            try button.replaceWith(submitInput(for: button))
        } else {
            try button.remove()
        }
    }

    private func isInsideForm(_ button: Element) -> Bool {
        var ancestor = button.parent()
        while let node = ancestor {
            if node.tagName() == "form" { return true }
            ancestor = node.parent()
        }
        return false
    }

    private func submitInput(for button: Element) throws -> Element {
        let input = try Element(Tag.valueOf("input"), "")
        try input.attr("type", "submit")
        let label = try button.text()
        try input.attr("value", label.isEmpty ? "Submit" : label)
        if button.hasAttr("name") {
            try input.attr("name", button.attr("name"))
        }
        return input
    }
}
