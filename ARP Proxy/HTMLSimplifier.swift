import Foundation
import SwiftSoup

/// Rewrites modern HTML into something a mid-90s browser can digest:
/// scripts, styles and other modern machinery removed, HTML5 semantic
/// containers turned into <div>s, lazy-loaded images resolved, and the
/// whole document serialized as pure ASCII with character entities.
nonisolated enum HTMLSimplifier {

    /// Pages larger than this are passed through unsimplified.
    private static let maxInputBytes = 8 * 1024 * 1024

    /// Elements that are invisible, unrenderable, or meaningless without
    /// CSS/JS. `<template>` content especially must go: vintage browsers
    /// would render it as visible text.
    private static let removedTags =
        "template, script, style, svg, canvas, video, audio, embed, object, source, track, dialog"

    /// Block-level HTML5 containers renamed to <div> (an HTML 3.2 tag) so
    /// vintage browsers keep the block layout instead of inlining everything.
    private static let renamedToDiv =
        "main, article, section, nav, aside, header, footer, figure, figcaption, hgroup, details, summary, search"

    /// Attributes that only mean something to CSS, JS or modern protocols.
    private static let droppedAttributes: Set<String> = [
        "class", "style", "role", "slot", "part", "is", "nonce",
        "async", "defer", "integrity", "crossorigin", "referrerpolicy",
        "ping", "tabindex", "hidden", "loading", "decoding", "fetchpriority",
        "srcset", "sizes", "autocomplete", "autofocus", "autocapitalize",
        "contenteditable", "draggable", "spellcheck", "translate",
        "itemprop", "itemscope", "itemtype", "itemid",
        "enterkeyhint", "inputmode", "popover", "popovertarget", "inert",
    ]

    /// Input types newer than HTML 4; unknown types default to text anyway,
    /// but being explicit avoids surprises in the strangest old browsers.
    private static let modernInputTypes: Set<String> = [
        "email", "url", "tel", "search", "number", "date", "time",
        "datetime-local", "month", "week", "color", "range",
    ]

    /// Typographic Unicode that pre-Unicode browsers can't show, mapped to
    /// ASCII stand-ins. Quotes map to entities so they stay safe inside
    /// attribute values.
    private static let substitutions: [(scalar: Unicode.Scalar, replacement: String)] = [
        ("\u{2018}", "&#39;"), ("\u{2019}", "&#39;"), ("\u{201A}", "&#39;"),
        ("\u{201C}", "&quot;"), ("\u{201D}", "&quot;"), ("\u{201E}", "&quot;"),
        ("\u{2013}", "-"), ("\u{2014}", "--"), ("\u{2026}", "..."),
        ("\u{2022}", "*"), ("\u{200B}", ""), ("\u{FEFF}", ""),
    ]

    private static let hexEntityPattern = try! NSRegularExpression(
        pattern: "&#[xX]([0-9a-fA-F]{1,6});")

    // MARK: - Entry point

    /// Returns a simplified ASCII rendition of the page, or nil when the
    /// body should be passed through untouched (too big, undecodable, or
    /// SwiftSoup failed).
    static func simplify(_ data: Data, contentType: String,
                         settings: ProxySettings) -> Data? {
        guard !data.isEmpty, data.count <= maxInputBytes,
              let html = decode(data, contentType: contentType)
        else { return nil }
        do {
            let doc = try SwiftSoup.parse(html)

            // Order matters: hidden-element removal reads style attributes,
            // lazy-image resolution reads data-* — both must run before the
            // attribute pruning pass wipes those attributes out.
            try removeInvisibleElements(doc)
            try resolveLazyImages(doc, stripDimensions: settings.stripImageDimensions)
            try replaceIframes(doc)
            try convertButtons(doc)
            try normalizeInputs(doc)

            // <noscript> content is exactly what a JS-less browser should
            // see; unwrap before the link/meta sweep so anything it spills
            // out (fallback stylesheets etc.) still gets removed.
            try doc.select("noscript").unwrap()
            try doc.select("picture > source").remove()
            try doc.select("picture").unwrap()
            try doc.select(removedTags).remove()
            try doc.select("link, meta").remove()

            for element in try doc.select(renamedToDiv).array() {
                _ = try element.tagName("div")
            }
            if settings.htmlVersion == .html32 {
                try downgradeToHTML32(doc)
            }
            try pruneAttributes(doc)
            try removeComments(doc)
            try setDoctype(doc, settings.htmlVersion)

            let settings = OutputSettings()
            _ = settings.charset(String.Encoding.ascii)
            _ = settings.escapeMode(Entities.EscapeMode.base)
            _ = settings.prettyPrint(pretty: false)
            doc.outputSettings(settings)

            var output = try doc.outerHtml()
            output = decimalizeHexEntities(output)  // Netscape 3 can't do &#x…;
            output = transliterate(output)
            output = escapeNonASCII(output)
            return Data(output.utf8)
        } catch {
            return nil
        }
    }

    // MARK: - DOM passes

    /// Content hidden by attribute or inline style must be dropped before
    /// styles are stripped, or dismissed banners and menus would suddenly
    /// become visible text.
    private static func removeInvisibleElements(_ doc: Document) throws {
        try doc.select("[hidden]").remove()
        for element in try doc.select("[style]").array() {
            let style = try element.attr("style").lowercased()
                .replacingOccurrences(of: " ", with: "")
            if style.contains("display:none") || style.contains("visibility:hidden") {
                try element.remove()
            }
        }
    }

    /// Promotes lazy-loading attributes into a real src, since no vintage
    /// browser will ever run the JavaScript that was meant to do it.
    private static func resolveLazyImages(_ doc: Document, stripDimensions: Bool) throws {
        for img in try doc.select("img").array() {
            // Modern sites size images with CSS, so width/height attributes
            // often describe a different crop than the served file (and the
            // proxy may downscale it besides). A vintage browser obeys them
            // literally, stretching the image — drop them and let it use the
            // delivered file's intrinsic size.
            if stripDimensions {
                try img.removeAttr("width")
                try img.removeAttr("height")
            }

            let src = try img.attr("src")
            guard src.isEmpty || src.hasPrefix("data:") else { continue }
            var replacement = ""
            for key in ["data-src", "data-lazy-src", "data-original"] where replacement.isEmpty {
                replacement = try img.attr(key)
            }
            if replacement.isEmpty {
                var srcset = try img.attr("srcset")
                if srcset.isEmpty { srcset = try img.attr("data-srcset") }
                replacement = firstSrcsetURL(srcset)
            }
            if !replacement.isEmpty, !replacement.hasPrefix("data:") {
                try img.attr("src", replacement)
            } else if !src.isEmpty {
                // data: URI with no usable alternative — unrenderable.
                try img.remove()
            }
        }
    }

    private static func firstSrcsetURL(_ srcset: String) -> String {
        guard let candidate = srcset.split(separator: ",").first else { return "" }
        return candidate.trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first.map(String.init) ?? ""
    }

    /// Vintage browsers ignore <iframe> tags; leave a link to the framed
    /// page instead of silently dropping the content.
    private static func replaceIframes(_ doc: Document) throws {
        for frame in try doc.select("iframe").array() {
            let src = try frame.attr("src")
            if src.hasPrefix("http") {
                let anchor = try Element(Tag.valueOf("a"), "")
                try anchor.attr("href", src)
                try anchor.appendText("[embedded: \(src)]")
                let paragraph = try Element(Tag.valueOf("p"), "")
                try paragraph.appendChild(anchor)
                try frame.replaceWith(paragraph)
            } else {
                try frame.remove()
            }
        }
    }

    /// <button> arrived with HTML 4; Netscape 3/4 can't submit with it.
    /// Inside a form it becomes <input type=submit>; elsewhere it could
    /// only ever have triggered JavaScript, so it goes away.
    private static func convertButtons(_ doc: Document) throws {
        for button in try doc.select("button").array() {
            let type = try button.attr("type").lowercased()
            var ancestor = button.parent()
            var insideForm = false
            while let node = ancestor {
                if node.tagName() == "form" { insideForm = true; break }
                ancestor = node.parent()
            }
            if insideForm, type != "button" {
                let input = try Element(Tag.valueOf("input"), "")
                try input.attr("type", "submit")
                let label = try button.text()
                try input.attr("value", label.isEmpty ? "Submit" : label)
                if button.hasAttr("name") {
                    try input.attr("name", button.attr("name"))
                }
                try button.replaceWith(input)
            } else {
                try button.remove()
            }
        }
    }

    private static func normalizeInputs(_ doc: Document) throws {
        for input in try doc.select("input").array()
        where modernInputTypes.contains(try input.attr("type").lowercased()) {
            try input.attr("type", "text")
        }
    }

    private static func pruneAttributes(_ doc: Document) throws {
        for element in try doc.getAllElements().array() {
            guard let attributes = element.getAttributes() else { continue }
            var doomed: [String] = []
            for attribute in attributes.asList() {
                let key = attribute.getKey().lowercased()
                if droppedAttributes.contains(key)
                    || key.hasPrefix("data-") || key.hasPrefix("aria-")
                    || key.hasPrefix("on") {
                    doomed.append(attribute.getKey())
                }
            }
            for key in doomed {
                try element.removeAttr(key)
            }
        }
    }

    /// HTML 3.2 predates a handful of inline tags from HTML 4; unwrap them
    /// (their content flows on) and turn <q> into literal quotation marks.
    private static func downgradeToHTML32(_ doc: Document) throws {
        for quote in try doc.select("q").array() {
            try quote.prependText("\"")
            try quote.appendText("\"")
        }
        try doc.select("q, abbr, acronym, ins, del, bdo, span").unwrap()
    }

    /// Declares the vintage dialect we now (approximately) speak, so old
    /// validators and browsers know what to expect.
    private static func setDoctype(_ doc: Document, _ version: ProxySettings.HTMLVersion) throws {
        var doctypes: [DocumentType] = []
        collect(doc) { node in
            if let doctype = node as? DocumentType { doctypes.append(doctype) }
        }
        for doctype in doctypes {
            try doctype.remove()
        }
        let doctype = switch version {
        case .html32:
            DocumentType("html", "-//W3C//DTD HTML 3.2 Final//EN", "", "")
        case .html401:
            DocumentType("html", "-//W3C//DTD HTML 4.01 Transitional//EN",
                         "http://www.w3.org/TR/html4/loose.dtd", "")
        }
        try doc.prependChild(doctype)
    }

    private static func removeComments(_ doc: Document) throws {
        var comments: [Comment] = []
        collect(doc) { node in
            if let comment = node as? Comment { comments.append(comment) }
        }
        for comment in comments {
            try comment.remove()
        }
    }

    private static func collect(_ node: Node, _ visit: (Node) -> Void) {
        visit(node)
        for child in node.getChildNodes() {
            collect(child, visit)
        }
    }

    // MARK: - Serialization

    /// Very old browsers only understand decimal character references.
    private static func decimalizeHexEntities(_ html: String) -> String {
        guard html.contains("&#x") || html.contains("&#X") else { return html }
        var result = ""
        var last = html.startIndex
        let matches = hexEntityPattern.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            guard let range = Range(match.range, in: html),
                  let hexRange = Range(match.range(at: 1), in: html),
                  let value = UInt32(html[hexRange], radix: 16)
            else { continue }
            result += html[last..<range.lowerBound]
            result += "&#\(value);"
            last = range.upperBound
        }
        result += html[last...]
        return result
    }

    private static func transliterate(_ html: String) -> String {
        var result = html
        for (scalar, replacement) in substitutions {
            result = result.replacingOccurrences(of: String(scalar), with: replacement)
            result = result.replacingOccurrences(of: "&#\(scalar.value);", with: replacement)
        }
        return result
    }

    /// Safety net: whatever the serializer left as raw non-ASCII becomes a
    /// decimal entity, guaranteeing a byte stream every charset can carry.
    private static func escapeNonASCII(_ html: String) -> String {
        guard html.contains(where: { !$0.isASCII }) else { return html }
        var result = ""
        result.reserveCapacity(html.count + 64)
        for scalar in html.unicodeScalars {
            if scalar.isASCII {
                result.unicodeScalars.append(scalar)
            } else {
                result += "&#\(scalar.value);"
            }
        }
        return result
    }

    // MARK: - Input decoding

    private static func decode(_ data: Data, contentType: String) -> String? {
        var encodings: [String.Encoding] = []
        if let name = charsetParameter(in: contentType) ?? metaCharset(in: data),
           let encoding = encoding(named: name) {
            encodings.append(encoding)
        }
        encodings += [.utf8, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) { return string }
        }
        return nil
    }

    private static func charsetParameter(in contentType: String) -> String? {
        guard let range = contentType.range(of: "charset=") else { return nil }
        let value = contentType[range.upperBound...]
            .prefix { !"; \"'".contains($0) }
        return value.isEmpty ? nil : String(value)
    }

    private static func metaCharset(in data: Data) -> String? {
        let prefix = String(decoding: data.prefix(2048), as: UTF8.self).lowercased()
        guard let range = prefix.range(of: "charset=") else { return nil }
        let value = prefix[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            .prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return value.isEmpty ? nil : String(value)
    }

    private static func encoding(named name: String) -> String.Encoding? {
        switch name.lowercased() {
        case "utf-8", "utf8": .utf8
        case "iso-8859-1", "latin1", "l1": .isoLatin1
        case "windows-1252", "cp1252", "x-cp1252": .windowsCP1252
        case "us-ascii", "ascii": .ascii
        case "shift_jis", "shift-jis", "sjis": .shiftJIS
        case "iso-2022-jp": .iso2022JP
        case "euc-jp": .japaneseEUC
        case "utf-16": .utf16
        default: nil
        }
    }
}
