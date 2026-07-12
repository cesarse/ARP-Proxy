import Foundation
import SwiftSoup

/// Removes elements that are invisible, unrenderable, or meaningless
/// without CSS/JS. `<template>` content especially must go: vintage
/// browsers would render it as visible text.
nonisolated struct RemoveModernTagsPass: HTMLPass {
    private static let removedTags =
        "template, script, style, svg, canvas, video, audio, embed, object, source, track, dialog"

    func run(on doc: Document) throws {
        try doc.select(Self.removedTags).remove()
        try doc.select("link, meta").remove()
    }
}
