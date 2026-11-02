//
//  CodeSuggestion.swift
//  swiftpy-views
//

import SwiftUI
import SyntaxHighlight

/// A completion and, where the provider knows it, what it names.
public struct CodeSuggestion: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case function, method, `class`, module, variable, property, keyword, constant
    }

    /// What replaces the query, as ``CodeCompletion/apply(_:to:at:indent:)`` takes it.
    public let text: String
    /// Nil where the source doesn't say, as the interpreter's completions don't.
    public let kind: Kind?
    /// What a call suggestion calls: it's shown above the others, where the
    /// signature help it turns into will be.
    public let signature: CodeSignatureHelp?

    public init(text: String, kind: Kind? = nil, signature: CodeSignatureHelp? = nil) {
        self.text = text
        self.kind = kind
        self.signature = signature
    }
}

extension CodeSuggestion.Kind {
    // Close to VS Code's codicons.
    var symbol: String {
        switch self {
        case .function, .method: "cube"
        case .class: "point.3.connected.trianglepath.dotted"
        case .module: "curlybraces"
        case .variable: "square.dashed.inset.filled"
        case .property: "wrench.adjustable"
        case .keyword: "text.alignleft"
        case .constant: "equal.square"
        }
    }

    /// The highlighter's scope for the kind's declaration; nil where highlight.js
    /// leaves the name uncolored (modules, variables, attributes).
    var scope: CodeScope? {
        switch self {
        case .function, .method: .title
        case .class: .titleClass
        case .keyword: .keyword
        case .constant: .literal
        case .module, .variable, .property: nil
        }
    }
}
