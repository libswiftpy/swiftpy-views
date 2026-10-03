//
//  CompletionFormatStyle.swift
//  swiftpy-views
//

import Foundation

/// Formats a raw completion for display in the suggestion list.
///
/// The tab fallback reads as "tab", and a callable whose paren is left open
/// for arguments (`print(`) reads `print(...)`, unlike one without (`clear()`).
public struct CompletionFormatStyle: FormatStyle {
    public init() {}

    public func format(_ value: String) -> String {
        if value == "\t" { return "tab" }
        return value.hasSuffix("(") ? value + "...)" : value
    }
}

public extension FormatStyle where Self == CompletionFormatStyle {
    static var completion: CompletionFormatStyle { CompletionFormatStyle() }
}
