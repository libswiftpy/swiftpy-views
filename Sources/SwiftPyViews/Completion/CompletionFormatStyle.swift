//
//  CompletionFormatStyle.swift
//  swiftpy-views
//

import Foundation

/// Formats a raw completion for display in the suggestion list.
///
/// The tab fallback reads as "tab", a dotted path as its last name, and a
/// callable whose paren is left open (`print(`) reads `print(...)`.
public struct CompletionFormatStyle: FormatStyle {
    public init() {}

    public func format(_ value: String) -> String {
        if value == "\t" { return "tab" }
        var name = value[...]
        if let dot = value.lastIndex(of: "."), value.index(after: dot) < value.endIndex {
            name = value[value.index(after: dot)...]
        }
        return name.hasSuffix("(") ? name + "...)" : String(name)
    }
}

public extension FormatStyle where Self == CompletionFormatStyle {
    static var completion: CompletionFormatStyle { CompletionFormatStyle() }
}
