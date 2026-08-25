import Foundation

/// Targets HTML 3.2 (Netscape 2/3, IE 3 era): additionally unwraps the
/// inline tags HTML 4 introduced, since 3.2 predates them.
nonisolated struct HTML32Simplifier: HTMLSimplifying {
    var doctype: DoctypeDeclaration {
        DoctypeDeclaration(publicId: "-//W3C//DTD HTML 3.2 Final//EN", systemId: "")
    }

    var vocabulary: Set<String> { HTMLVocabulary.html32 }

    var versionPasses: [any HTMLPass] {
        [DowngradeHTML4InlineTagsPass()]
    }
}
