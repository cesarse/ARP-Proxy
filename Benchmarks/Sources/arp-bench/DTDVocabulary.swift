@testable import ARPProxyHTML
import Foundation

/// The element names a target dialect actually defines. Anything else in the
/// output would make a vintage browser render tags it has never heard of, so
/// the benchmark treats it as a hard failure rather than a metric.
nonisolated struct DTDVocabulary: Sendable {
    let name: String
    let elements: Set<String>

    static func vocabulary(for version: HTMLVersion) -> DTDVocabulary {
        switch version {
        case .html32: html32
        case .html401: html401Transitional
        }
    }

    /// W3C REC-html32-19970114.
    static let html32 = DTDVocabulary(name: "HTML 3.2", elements: [
        "html", "head", "title", "base", "isindex", "link", "meta", "style",
        "script", "body", "div", "center", "blockquote", "form", "hr", "table",
        "address", "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "dir",
        "menu", "li", "dl", "dt", "dd", "pre", "tt", "i", "b", "u", "strike",
        "big", "small", "sub", "sup", "em", "strong", "dfn", "code", "samp",
        "kbd", "var", "cite", "font", "basefont", "br", "a", "img", "applet",
        "param", "map", "area", "input", "select", "option", "textarea",
        "caption", "tr", "th", "td",
    ])

    /// W3C HTML 4.01 Transitional — a superset of 3.2, so it is expressed as
    /// one: the loose DTD keeps every deprecated presentational element.
    static let html401Transitional = DTDVocabulary(
        name: "HTML 4.01 Transitional",
        elements: html32.elements.union([
            "abbr", "acronym", "bdo", "button", "col", "colgroup", "del",
            "fieldset", "iframe", "ins", "label", "legend", "noframes",
            "noscript", "object", "optgroup", "q", "s", "span", "tbody",
            "tfoot", "thead", "object",
        ]))

    /// Legal in one or both DTDs, yet a bug if the pipeline lets one reach the
    /// browser — each is the responsibility of a named pass. Checked
    /// separately from vocabulary so a failure points at the pass that broke.
    static let forbidden: Set<String> = [
        "script", "style", "link", "meta",     // RemoveModernTagsPass
        "svg", "canvas", "video", "audio",     // RemoveModernTagsPass
        "embed", "object", "template",         // RemoveModernTagsPass
        "source", "track", "dialog",           // RemoveModernTagsPass
        "iframe",                              // ReplaceIframesPass
        "button",                              // ConvertButtonsPass
        "noscript",                            // UnwrapNoscriptPass
        "picture",                             // FlattenPicturePass
    ]

    /// Inline tags HTML 4 introduced that 3.2 predates; only the 3.2 dialect
    /// runs the pass that unwraps them.
    static let html4Inline: Set<String> = [
        "q", "abbr", "acronym", "ins", "del", "span", "bdo",
    ]
}
