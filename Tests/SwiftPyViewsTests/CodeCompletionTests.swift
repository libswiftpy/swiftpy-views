//
//  CodeCompletionTests.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026. 07. 28..
//
//  The rule: completion only happens when the caret sits at the end of an
//  identifier — that is, when the next character is not an identifier
//  character (alphanumerics, "_" and "."). A caret in the middle of a word
//  offers nothing. That keeps query and apply inverses of one range, since
//  the identifier never extends past the caret.
//

import Testing
import SwiftUI
@testable import SwiftPyViews

private extension String {
    /// The index `offset` characters from the start.
    func at(_ offset: Int) -> String.Index {
        index(startIndex, offsetBy: offset)
    }

    var end: String.Index { endIndex }
}

@Suite("Cursor: extraction")
struct CursorQueryTests {
    @Test("A caret inside an identifier has nothing to complete", arguments: [
        ("print(hello)", 9),   // print(hel|lo)
        ("x = range(", 7),     // x = ran|ge(
        ("os.path", 2),        // os|.path — "." continues the identifier
        ("ran", 0),            // |ran
        ("ran", 1),            // r|an
        ("x = ran", 4),        // x = |ran
        ("a[0", 2),            // a[|0
    ])
    func midIdentifier(source: String, offset: Int) {
        #expect(CodeCompletion.query(in: source, at: source.at(offset)) == "")
    }

    @Test("Reads the identifier ending at the caret", arguments: [
        ("foo bar", 3, "foo"),         // foo| bar
        ("print(hello)", 11, "hello"), // print(hello|) — ")" ends the identifier
        ("a(b) c", 3, "b"),            // a(b|) c
        ("a[0", 3, "0"),               // a[0|
    ])
    func endOfIdentifier(source: String, offset: Int, expected: String) {
        #expect(CodeCompletion.query(in: source, at: source.at(offset)) == expected)
    }

    @Test("A caret at the end behaves as it does without a cursor")
    func atEnd() {
        #expect(CodeCompletion.query(in: "x = ran", at: "x = ran".end) == "ran")
        #expect(CodeCompletion.query(in: "os.pa", at: "os.pa".end) == "os.pa")
    }
}

@Suite("Cursor: applying a suggestion")
struct CursorApplyTests {
    @Test("Replaces only the identifier at the caret, keeping the rest")
    func keepsSurroundingText() {
        let source = "ran = 1"
        let result = CodeCompletion.apply("ranges", to: source, at: source.at(3))

        #expect(result.source == "ranges = 1")
        #expect(result.cursor == result.source.at(6))
    }

    @Test("An argument-taking callable closes its paren, caret inside")
    func openParenCallableCaretInside() {
        let source = "pri"
        let result = CodeCompletion.apply("print(", to: source, at: source.end)

        #expect(result.source == "print()")           // paren closed
        #expect(result.cursor == result.source.at(6))  // between the parens
    }

    @Test("A zero-argument callable keeps the caret after its parens")
    func closedParenCallableCaretAfter() {
        let source = "cle"
        let result = CodeCompletion.apply("clear()", to: source, at: source.end)

        #expect(result.source == "clear()")
        #expect(result.cursor == result.source.at(7))  // after the parens
    }

    @Test("Tab indents at the caret rather than at the line end")
    func tabAtCaret() {
        let source = "ab"
        let result = CodeCompletion.apply("\t", to: source, at: source.at(1))

        #expect(result.source == "a\tb")
        #expect(result.cursor == result.source.at(2))
    }
}
