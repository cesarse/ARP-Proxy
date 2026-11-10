import Foundation
import SwiftSoup

/// Turns a detected grid into the table a 1997 site would have used.
///
/// Every attribute here is presentational on purpose: `border`, `cellpadding`,
/// `width` and `valign` are how layout was expressed before CSS, they are
/// valid in HTML 3.2, and `PruneAttributesPass` keeps them because it works
/// from a denylist.
nonisolated struct TableLayoutBuilder {
    /// Vintage screens were 640×480 or 800×600. Three columns leaves roughly
    /// 200 px a cell, which is tight but readable; four is not.
    private static let maximumColumns = 3

    /// Usable width on a 640 px screen, once window chrome and a scrollbar
    /// are gone. Columns are sized against this rather than the viewport,
    /// which no proxy can know.
    private static let vintagePageWidth = 600

    func apply(_ candidate: GridCandidate) throws {
        let members = candidate.members
        guard members.count >= 2, let anchor = members.first else { return }
        let columns = min(Self.maximumColumns, members.count)
        let table = try makeTable(columns: columns)

        // A <table> may not sit inside a list, so when the members are list
        // items the table goes before the list, which is then left empty.
        let list = candidate.parent
        let parentIsList = ["ul", "ol"].contains(list.tagName())
        try (parentIsList ? list : anchor).before(table)

        var row = try makeRow(in: table)
        for (index, member) in members.enumerated() {
            if index > 0, index % columns == 0 {
                row = try makeRow(in: table)
            }
            let cell = try Element(Tag.valueOf("td"), "")
            try cell.attr("valign", "top")
            try cell.attr("width", "\(100 / columns)%")
            // <li> is meaningless outside a list; the cell is the list now.
            if member.tagName() == "li" {
                _ = try member.tagName("div")
            }
            try cell.appendChild(member)
            try constrainImages(in: cell, columns: columns)
            try row.appendChild(cell)
        }

        if parentIsList, list.children().isEmpty() {
            try list.remove()
        }
    }

    /// A cell is only as narrow as its widest image. `ResolveLazyImagesPass`
    /// has already stripped width/height by this point, so the browser falls
    /// back to the file's intrinsic size — BBC serves 480 px photos, which
    /// would make a three-column table 1,400 px wide and hide two thirds of
    /// the page behind a horizontal scrollbar.
    ///
    /// Setting `width` alone, never `height`, leaves the browser to scale the
    /// image on its own aspect ratio. A plain pixel count is what HTML 3.2
    /// allows; percentages arrived with 4.01.
    private func constrainImages(in cell: Element, columns: Int) throws {
        let width = Self.vintagePageWidth / columns - 10
        for image in try cell.select("img").array() where !image.hasAttr("width") {
            try image.attr("width", "\(width)")
        }
    }

    private func makeTable(columns: Int) throws -> Element {
        let table = try Element(Tag.valueOf("table"), "")
        try table.attr("border", "0")
        try table.attr("cellpadding", "4")
        try table.attr("cellspacing", "0")
        try table.attr("width", "100%")
        return table
    }

    /// Rows are appended straight to <table>: HTML 3.2 has no <tbody>, and
    /// building the nodes by hand rather than parsing a fragment keeps
    /// SwiftSoup's HTML5 tree construction from inserting one.
    private func makeRow(in table: Element) throws -> Element {
        let row = try Element(Tag.valueOf("tr"), "")
        try table.appendChild(row)
        return row
    }
}
