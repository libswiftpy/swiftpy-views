import Testing
import Foundation
@testable import SwiftPyViews

@MainActor
struct CodeEditorTests {
    @Test func cursorIsTheCaretPastAMultiByteCharacter() {
        let editor = CodeEditor(source: "a👍b")
        // The thumb is two UTF-16 units, so the caret after it is at 3.
        editor.selection = NSRange(location: 3, length: 0)

        #expect(editor.cursor == editor.source.index(editor.source.startIndex, offsetBy: 2))
    }

    @Test func cursorIsNilForARangeSelection() {
        let editor = CodeEditor(source: "print(1)")
        editor.selection = NSRange(location: 0, length: 5)

        #expect(editor.cursor == nil)
    }

    @Test func cursorIsNilForASelectionLeftBehindByAnEdit() {
        let editor = CodeEditor(source: "print(1)")
        editor.selection = NSRange(location: 40, length: 0)

        #expect(editor.cursor == nil)
    }
}

@Suite struct CodeIndentTests {
    /// The caret is written as `|` and taken out before the call.
    private func split(_ marked: String) -> (NSString, Int) {
        let location = (marked as NSString).range(of: "|").location
        return (marked.replacingOccurrences(of: "|", with: "") as NSString, location)
    }

    @Test(arguments: [
        ("if something:|", "\n    "),
        ("    if x:|", "\n        "),
        ("    if x:   |", "\n        "),
        ("        x = 1|", "\n        "),
        ("x = 1|", "\n"),
        ("|    x = 1", "\n"),
        ("d = {1: 2}|", "\n"),
        ("    x = 1|\nnext", "\n    "),
        ("    x = |1", "\n    "),
    ])
    func newlineCarriesTheIndent(marked: String, expected: String) {
        let (text, location) = split(marked)
        #expect(CodeIndent.newline(in: text, at: location) == expected)
    }

    @Test func backspaceDropsTheLineToThePreviousLevel() throws {
        // Six spaces, caret, two spaces: the whole indent goes to four and the
        // spaces past the caret go with it.
        let (text, location) = split("      |  print")
        let target = try #require(CodeIndent.outdent(in: text, at: location))

        #expect(target == NSRange(location: 4, length: 4))
        #expect(text.replacingCharacters(in: target, with: "") == "    print")
    }

    @Test(arguments: [
        ("        |print", NSRange(location: 4, length: 4)),
        ("    |print", NSRange(location: 0, length: 4)),
        ("      |print", NSRange(location: 4, length: 2)),
        ("  |print", NSRange(location: 0, length: 2)),
        ("x\n        |print", NSRange(location: 6, length: 4)),
    ])
    func outdentSnapsToTheStopBelow(marked: String, expected: NSRange) {
        let (text, location) = split(marked)
        #expect(CodeIndent.outdent(in: text, at: location) == expected)
    }

    @Test(arguments: [
        "|    print",       // column zero joins with the line above instead
        "    print|",       // past the text, so an ordinary delete
        "    pr|int",
        "x = |1",
    ])
    func outdentDeclinesOutsideTheIndentation(marked: String) {
        let (text, location) = split(marked)
        #expect(CodeIndent.outdent(in: text, at: location) == nil)
    }
}

@Suite struct CodePairsTests {
    private func split(_ marked: String) -> (NSString, Int) {
        let location = (marked as NSString).range(of: "|").location
        return (marked.replacingOccurrences(of: "|", with: "") as NSString, location)
    }

    @Test(arguments: [
        ("print|", "(", ")"),
        ("x = |", "[", "]"),
        ("x = |", "{", "}"),
        ("x = |", "\"", "\""),
        ("x = |", "'", "'"),
        ("print(|)", "(", ")"),     // nested, the closer ahead is not a word
        ("f(|, b)", "(", ")"),
        ("x = | + 1", "(", ")"),
    ])
    func openerBringsItsCloser(marked: String, typed: String, closer: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == .close(closer))
    }

    @Test(arguments: [
        ("print(|)", ")"),
        ("x = [|]", "]"),
        ("x = {|}", "}"),
        ("x = \"|\"", "\""),
        ("x = '|'", "'"),
    ])
    func closerStepsOverTheOneAlreadyThere(marked: String, typed: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == .skip)
    }

    @Test(arguments: [
        ("|foo", "("),          // the closer would land against a word
        ("x = |name", "\""),
        ("don|", "'"),          // an apostrophe inside a word
        ("''|", "'"),           // opening a triple quote by hand
        ("print()|", ")"),      // nothing to step over
        ("x = 1|", ")"),
        ("x = |", "a"),         // not a pairing character at all
        ("x = |", "ab"),        // a paste is left alone
        ("x = |", ""),
    ])
    func leavesEverythingElseAlone(marked: String, typed: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == nil)
    }

    @Test func aQuoteBeforeAnEmojiIsNotSplit() {
        let (text, location) = split("x = |👍")
        // The emoji's leading surrogate counts as a word character, so the
        // closer isn't wedged in front of it.
        #expect(CodePairs.edit(typing: "\"", in: text, at: location) == nil)
    }
}
