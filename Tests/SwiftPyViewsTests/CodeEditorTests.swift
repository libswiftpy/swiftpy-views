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

    @Test func applyingReplacesTheIdentifierAndLeavesTheCaretInside() {
        let editor = CodeEditor(source: "pri")
        editor.selection = NSRange(location: 3, length: 0)

        editor.apply("print(")

        #expect(editor.source == "print()")
        #expect(editor.selection == NSRange(location: 6, length: 0))
    }

    @Test func applyingAZeroArgumentCallableKeepsTheCaretAfterIt() {
        let editor = CodeEditor(source: "cle")
        editor.selection = NSRange(location: 3, length: 0)

        editor.apply("clear()")

        #expect(editor.source == "clear()")
        #expect(editor.selection == NSRange(location: 7, length: 0))
    }

    @Test func applyingPastAMultiByteCharacterLandsOnTheRightOffset() {
        let editor = CodeEditor(source: "a👍 ra")
        // The thumb is two UTF-16 units, so the caret after "ra" is at 6.
        editor.selection = NSRange(location: 6, length: 0)

        editor.apply("range(")

        #expect(editor.source == "a👍 range()")
        // UTF-16 again: the caret sits between the parens, past the thumb.
        #expect(editor.selection == NSRange(location: 10, length: 0))
    }

    @Test func theTabFallbackIndentsAsTheTabKeyDoes() {
        let editor = CodeEditor(source: "if x:\n")
        editor.selection = NSRange(location: 6, length: 0)

        editor.apply("\t")

        // Four spaces, not a tab: the Tab key puts in the same.
        #expect(editor.source == "if x:\n    ")
        #expect(editor.selection == NSRange(location: 10, length: 0))
    }

    @Test func applyingWithARangeSelectionDoesNothing() {
        let editor = CodeEditor(source: "ran = 1")
        editor.selection = NSRange(location: 0, length: 3)

        editor.apply("ranges")

        #expect(editor.source == "ran = 1")
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
        ("    x = 1|\nnext", "\n    "),
        ("    x = |1", "\n    "),
    ])
    func newlineCarriesTheIndent(marked: String, expected: String) {
        let (text, location) = split(marked)
        // The caret lands at the end of what went in.
        #expect(CodeIndent.newline(in: text, at: location)
                == .init(text: expected, caret: expected.utf16.count))
    }

    @Test(arguments: [
        "x = 1|",
        "|    x = 1",
        "d = {1: 2}|",       // a colon that isn't at the end opens nothing
        "\"|\"",              // a newline inside a string is a syntax error
        "'|'",
    ])
    func aPlainNewlineIsLeftToThePlatform(marked: String) {
        let (text, location) = split(marked)
        #expect(CodeIndent.newline(in: text, at: location) == nil)
    }

    @Test(arguments: [
        ("(|)", "\n    \n", 5),
        ("[|]", "\n    \n", 5),
        ("{|}", "\n    \n", 5),
        ("    foo(|)", "\n        \n    ", 9),
    ])
    func abracketOpensOutOverThreeLines(marked: String, expected: String, caret: Int) {
        let (text, location) = split(marked)
        #expect(CodeIndent.newline(in: text, at: location)
                == .init(text: expected, caret: caret))
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

@Suite struct CodePairDeletionTests {
    private func split(_ marked: String) -> (NSString, Int) {
        let location = (marked as NSString).range(of: "|").location
        return (marked.replacingOccurrences(of: "|", with: "") as NSString, location)
    }

    @Test(arguments: [
        ("(|)", NSRange(location: 0, length: 2)),
        ("[|]", NSRange(location: 0, length: 2)),
        ("{|}", NSRange(location: 0, length: 2)),
        ("\"|\"", NSRange(location: 0, length: 2)),
        ("'|'", NSRange(location: 0, length: 2)),
        ("    foo(|)", NSRange(location: 7, length: 2)),
    ])
    func backspaceTakesTheEmptyPairWhole(marked: String, expected: NSRange) {
        let (text, location) = split(marked)
        #expect(CodePairs.emptyPair(in: text, at: location) == expected)
    }

    @Test(arguments: [
        "(a|)",        // not empty
        "(|",          // nothing ahead
        "|)",          // nothing behind
        "(|]",         // mismatched
        "x = 1|",
        "|",
    ])
    func everythingElseDeletesOneCharacter(marked: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.emptyPair(in: text, at: location) == nil)
    }
}

@Suite struct CodePairContextTests {
    private func split(_ marked: String) -> (NSString, Int) {
        let location = (marked as NSString).range(of: "|").location
        return (marked.replacingOccurrences(of: "|", with: "") as NSString, location)
    }

    @Test(arguments: [
        ("x = f|", "\"", "\""),
        ("x = f|", "'", "'"),
        ("x = rb|", "\"", "\""),
        ("x = B|", "'", "'"),
        ("x = FR|", "\"", "\""),
        ("print(f|", "'", "'"),
    ])
    func aStringPrefixStillOpensAQuote(marked: String, typed: String, closer: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == .close(closer))
    }

    @Test(arguments: [
        ("x = xf|", "\""),      // not a prefix, so it reads as a word
        ("if|", "'"),
        ("don|", "'"),
    ])
    func anOrdinaryWordBeforeAQuoteDoesNot(marked: String, typed: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == nil)
    }

    @Test(arguments: [
        ("x = \"hello |\"", "'"),        // an apostrophe in prose
        ("x = 'hello |'", "\""),
        ("x = \"hello |\"", "("),        // a paren in a message
        ("x = \"hello |\"", "["),
        ("x = f\"a |\"", "'"),
        ("x = \"it\\\"s |\"", "'"),      // the escaped quote didn't end it
        ("# note |", "'"),
        ("x = 1  # it |", "("),
    ])
    func nothingPairsInsideAStringOrComment(marked: String, typed: String) {
        let (text, location) = split(marked)
        #expect(CodePairs.edit(typing: typed, in: text, at: location) == nil)
    }

    @Test func theClosingQuoteStillStepsOver() {
        // Typing the string's own quote at its end closes it, as before.
        let (text, location) = split("x = \"hello |\"")
        #expect(CodePairs.edit(typing: "\"", in: text, at: location) == .skip)
    }

    @Test func pairingResumesAfterTheStringEnds() {
        let (text, location) = split("x = \"a\" + |")
        #expect(CodePairs.edit(typing: "'", in: text, at: location) == .close("'"))
    }

    @Test(arguments: [
        ("x = |", CodePairs.Context.code),
        ("x = \"a|", .string(quote: 0x22)),
        ("x = 'a|", .string(quote: 0x27)),
        ("x = \"a\" |", .code),
        ("x = \"a\\\"b|", .string(quote: 0x22)),
        ("# a |", .comment),
        ("x = \"# not a comment|", .string(quote: 0x22)),
    ])
    func contextReadsTheLine(marked: String, expected: CodePairs.Context) {
        let (text, location) = split(marked)
        #expect(CodePairs.context(in: text, at: location) == expected)
    }
}
