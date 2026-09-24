//
//  CodeCompletion.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026. 07. 28..
//

import Foundation

/// The pure text rules behind autocomplete.
///
/// Completion only acts when the caret sits at the end of an identifier — when
/// the next character is not an identifier character (alphanumerics, `_` and
/// `.`). ``query(in:at:)`` reads that identifier and ``apply(_:to:at:)``
/// overwrites it; keeping them as inverses over one range is what stops the two
/// from drifting apart.
public enum CodeCompletion {
    /// The fragment to send to the interpreter's `complete` command.
    public static func query(in source: String, at cursor: String.Index) -> String {
        guard let range = identifierRange(in: source, endingAt: cursor) else {
            return ""
        }

        // debugDescription escapes embedded quotes and backslashes before the
        // fragment crosses into the interpreter; the trim drops the wrapping
        // quotes it adds.
        return String(source[range])
            .debugDescription
            .trimmingCharacters(in: CharacterSet(["\""]))
    }

    /// Applies a tapped suggestion by overwriting the identifier that
    /// ``query(in:at:)`` read. rlcompleter encodes a callable's arity in its
    /// parens: a trailing `(` (takes arguments) is closed with the caret left
    /// between the parens, while a closed `()` (no arguments) keeps the caret
    /// after them.
    public static func apply(
        _ completion: String,
        to source: String,
        at cursor: String.Index
    ) -> (source: String, cursor: String.Index) {
        // The tab fallback inserts an actual tab for indentation.
        if completion == "\t" {
            let cursorOffset = source.distance(from: source.startIndex, to: cursor)
            let applied = String(source[..<cursor]) + completion + String(source[cursor...])
            return (applied, applied.index(applied.startIndex, offsetBy: cursorOffset + completion.count))
        }

        // Close an open callable paren, remembering to leave the caret inside.
        let insert: String
        let caretWithinInsert: Int
        if completion.hasSuffix("(") {
            insert = completion + ")"
            caretWithinInsert = completion.count // right after "(", before ")"
        } else {
            insert = completion
            caretWithinInsert = completion.count // end (covers "()" and plain names)
        }

        let range = identifierRange(in: source, endingAt: cursor) ?? cursor..<cursor
        let applied = String(source[..<range.lowerBound]) + insert + String(source[range.upperBound...])
        let insertionStart = source.distance(from: source.startIndex, to: range.lowerBound)
        let newCursorOffset = insertionStart + caretWithinInsert
        return (applied, applied.index(applied.startIndex, offsetBy: newCursorOffset))
    }

    /// The range of the identifier ending at `cursor`, or `nil` when the caret
    /// sits inside an identifier rather than at its end.
    private static func identifierRange(
        in source: String,
        endingAt cursor: String.Index
    ) -> Range<String.Index>? {
        guard !hasIdentifierCharacter(in: source, at: cursor) else {
            return nil
        }

        var start = cursor
        while start > source.startIndex {
            let previous = source.index(before: start)
            guard isIdentifierCharacter(source[previous]) else { break }
            start = previous
        }

        return start..<cursor
    }

    private static func hasIdentifierCharacter(in source: String, at index: String.Index) -> Bool {
        guard index < source.endIndex else { return false }
        return isIdentifierCharacter(source[index])
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "_" || character == "." || character.isLetter || character.isNumber
    }
}
