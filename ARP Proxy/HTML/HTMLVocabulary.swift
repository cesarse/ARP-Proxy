import Foundation

/// The element names each target dialect actually defines. A dialect is not
/// just a DOCTYPE string: emitting one is a promise about which tags are
/// inside, and `UnwrapUnknownElementsPass` is what keeps it.
nonisolated enum HTMLVocabulary {

    /// W3C REC-html32-19970114.
    static let html32: Set<String> = [
        "html", "head", "title", "base", "isindex", "link", "meta", "style",
        "script", "body", "div", "center", "blockquote", "form", "hr", "table",
        "address", "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "dir",
        "menu", "li", "dl", "dt", "dd", "pre", "tt", "i", "b", "u", "strike",
        "big", "small", "sub", "sup", "em", "strong", "dfn", "code", "samp",
        "kbd", "var", "cite", "font", "basefont", "br", "a", "img", "applet",
        "param", "map", "area", "input", "select", "option", "textarea",
        "caption", "tr", "th", "td",
    ]

    /// HTML 4.01 Transitional. The loose DTD keeps every deprecated
    /// presentational element, so it is a strict superset of 3.2.
    static let html401Transitional: Set<String> = html32.union([
        "abbr", "acronym", "bdo", "button", "col", "colgroup", "del",
        "fieldset", "iframe", "ins", "label", "legend", "noframes", "noscript",
        "object", "optgroup", "q", "s", "span", "tbody", "tfoot", "thead",
    ])
}
