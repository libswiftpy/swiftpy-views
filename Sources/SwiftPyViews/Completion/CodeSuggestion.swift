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

/// What a suggestion names, as its provider resolves it.
public struct CodeSuggestionDetails: Hashable, Sendable {
    /// Its declaration, such as `def print(*values: object) -> None`.
    public let signature: String?
    /// Plain text or Markdown; its first paragraphs are shown.
    public let documentation: String?

    public init(signature: String?, documentation: String?) {
        let trim = { (text: String?) in
            text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        self.signature = trim(signature)
        self.documentation = trim(documentation)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension CodeSuggestion {
    /// The name the row shows: past the query's dots, without a call's parens.
    var displayName: String {
        var name = Substring(text)
        if name.hasSuffix("()") { name = name.dropLast(2) } else if name.hasSuffix("(") { name = name.dropLast() }
        if let dot = name.lastIndex(of: ".") { name = name[name.index(after: dot)...] }
        return String(name)
    }

    /// A call's parameters by name, dimmed after it: `(*values, sep, end)`.
    var displayParameters: String? {
        guard let label = signature?.current.label else { return nil }
        return Self.parameterNames(in: label)
    }

    /// What's completed with a call: its parameters are worth showing.
    var isCallable: Bool {
        signature != nil || [.function, .method, .class].contains(kind)
    }

    /// `(a: int, b=1, *args, **kw) -> None` as `(a, b, *args, **kw)`; nil
    /// for a label without parens.
    static func parameterNames(in label: String) -> String? {
        guard let open = label.firstIndex(of: "(") else { return nil }
        var depth = 0, current = "", names: [String] = []
        var close: String.Index?
        func finish() {
            let part = current.trimmingCharacters(in: .whitespaces)
            current = ""
            guard !part.isEmpty else { return }
            let end = part.firstIndex { $0 == ":" || $0 == "=" } ?? part.endIndex
            names.append(part[..<end].trimmingCharacters(in: .whitespaces))
        }
        for index in label[label.index(after: open)...].indices {
            let character = label[index]
            switch character {
            case "(", "[", "{": depth += 1
            case ")", "]", "}":
                if depth == 0 { close = index } else { depth -= 1 }
            case "," where depth == 0:
                finish()
                continue
            default: break
            }
            if close != nil { break }
            current.append(character)
        }
        guard close != nil else { return nil }
        finish()
        // A method's receiver isn't passed.
        if let first = names.first, first == "self" || first == "cls" { names.removeFirst() }
        return "(" + names.joined(separator: ", ") + ")"
    }
}

extension CodeSuggestion.Kind {
    /// The icon's color: its declaration's highlight, or secondary where it has none.
    func iconStyle(in colorScheme: ColorScheme) -> AnyShapeStyle {
        guard let scope else { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(SwiftUI.Color(CodePalette.xcode.color(for: scope, in: colorScheme)))
    }
}
