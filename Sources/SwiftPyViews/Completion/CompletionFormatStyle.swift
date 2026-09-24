//
//  CompletionFormatStyle.swift
//  swiftpy-views
//

import Foundation

/// Formats a raw completion for display in the suggestion list.
///
/// The tab fallback reads as "tab", and rlcompleter leaves an argument-taking
/// callable's paren open (`print(`), so it is closed to read `print()`.
public struct CompletionFormatStyle: FormatStyle {
    public init() {}

    public func format(_ value: String) -> String {
        if value == "\t" { return "tab" }
        return value.hasSuffix("(") ? value + ")" : value
    }
}

public extension FormatStyle where Self == CompletionFormatStyle {
    static var completion: CompletionFormatStyle { CompletionFormatStyle() }
}
