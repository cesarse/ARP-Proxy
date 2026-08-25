import Foundation

/// Targets HTML 4.01 Transitional (Netscape 4.5+, IE 4/5 era): the common
/// pipeline already produces valid 4.01, so no extra passes needed.
nonisolated struct HTML401Simplifier: HTMLSimplifying {
    var doctype: DoctypeDeclaration {
        DoctypeDeclaration(publicId: "-//W3C//DTD HTML 4.01 Transitional//EN",
                           systemId: "http://www.w3.org/TR/html4/loose.dtd")
    }

    var vocabulary: Set<String> { HTMLVocabulary.html401Transitional }

    var versionPasses: [any HTMLPass] {
        []
    }
}
