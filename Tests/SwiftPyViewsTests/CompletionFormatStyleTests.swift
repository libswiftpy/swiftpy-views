//
//  CompletionFormatStyleTests.swift
//  PyPrompt
//

import Testing
@testable import SwiftPyViews

@Suite("Completion display formatting")
struct CompletionFormatStyleTests {
    @Test("Formats raw completions for display", arguments: [
        ("\t", "tab"),          // tab fallback
        ("print(", "print()"),  // argument-taking callable closes its paren
        ("clear()", "clear()"), // zero-argument callable is shown as-is
        ("value", "value"),     // non-callable stays plain
    ])
    func formats(raw: String, expected: String) {
        #expect(CompletionFormatStyle().format(raw) == expected)
    }
}
