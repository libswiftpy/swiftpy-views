import Testing
import Foundation
import SwiftUI
import SyntaxHighlight
@testable import SwiftPyViews

@MainActor
struct CodeEditorTests {
    @Test func cursorIsTheCaretPastAMultiByteCharacter() {
        let editor = CodeEditor(source: "a👍b")
        // The thumb is two UTF-16 units, so the caret after it is at 3.
        editor.selection = NSRange(location: 3, length: 0)

        #expect(editor.cursor == editor.source.index(editor.source.startIndex, offsetBy: 2))
    }

    @Test func markersKeepTheirStyle() {
        let editor = CodeEditor(source: "import json")
        editor.setMarkers([
            CodeMarker(line: 1, column: 8, endLine: 1, endColumn: 12, style: .faded),
            CodeMarker(line: 1, column: 1, endLine: 1, endColumn: 7, color: .red),
        ], for: editor.source)
        #expect(editor.marked.marks.map(\.style) == [.faded, .underline])
        #expect(editor.marked.marks.first?.range == NSRange(location: 7, length: 4))
    }

    @Test func fadedMarksMoveWithTheTextAndUnderlinesGo() {
        let editor = CodeEditor(source: "import json\nx = 1")
        editor.setMarkers([
            CodeMarker(line: 1, column: 8, endLine: 1, endColumn: 12, style: .faded),
            CodeMarker(line: 2, column: 1, endLine: 2, endColumn: 2, color: .red),
        ], for: editor.source)

        editor.source = "# top\nimport json\nx = 1"
        #expect(editor.marked.source == editor.source)
        #expect(editor.marked.marks.map(\.range) == [NSRange(location: 13, length: 4)])

        // An edit inside the faded name drops it.
        editor.source = "# top\nimport jsn\nx = 1"
        #expect(editor.marked.marks.isEmpty)
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

@MainActor
struct SignatureHelpTests {
    @Test func wrappingPreservesAllTextAndFindsTheActiveLine() throws {
        let label = "(name: str = '👍', count: int = 1, separator: str = ', ', flush: bool = False) -> str"
        let signature = CodeSignature(label: label, activeParameter: (label as NSString).range(of: "flush: bool = False"))
        let lines = SignatureLine.wrap(signature, width: 160, fontSize: 17)
        #expect(lines.count > 3)
        #expect(lines.map { (label as NSString).substring(with: $0.range) }.joined() == label)
        let active = try #require(signature.activeParameter)
        let activeLine = try #require(lines.firstIndex { NSLocationInRange(active.location, $0.range) })
        #expect(activeLine >= 3)
        #expect(lines.allSatisfy { $0.height > 0 })
    }

    @Test func overloadsKeepTheSelectedOneOrFallBackToTheFirst() throws {
        let one = CodeSignature(label: "(a: int)"), two = CodeSignature(label: "(a: str, b: str)")
        #expect(try #require(CodeSignatureHelp(signatures: [one, two], selected: 1)).current == two)
        #expect(try #require(CodeSignatureHelp(signatures: [one, two], selected: 5)).current == one)
        #expect(CodeSignatureHelp(signatures: []) == nil)
    }

    @Test func widerSignaturesNeedFewerLinesAndLargeTextNeedsMore() {
        let signature = CodeSignature(label: "(first: str, second: str, third: bool = False) -> None")
        let narrow = SignatureLine.wrap(signature, width: 200, fontSize: 13)
        let wide = SignatureLine.wrap(signature, width: 1000, fontSize: 13)
        let large = SignatureLine.wrap(signature, width: 200, fontSize: 30)
        #expect(wide.count == 1)
        #expect(narrow.count > wide.count)
        #expect(large.count > narrow.count)
    }

    @Test func longIdentifiersWrapWithoutDroppingCharacters() {
        let label = "(" + String(repeating: "veryLongParameter", count: 12) + ": str)"
        let lines = SignatureLine.wrap(CodeSignature(label: label), width: 100, fontSize: 17)
        #expect(lines.count > 3)
        #expect(lines.map { (label as NSString).substring(with: $0.range) }.joined() == label)
    }

    @Test func emphasisPreservesSyntaxColorsAndUnicode() throws {
        let label = "(a: str = '👍', b: int)"
        let range = (label as NSString).range(of: "b: int")
        let signature = CodeSignature(label: label, activeParameter: range)
        let formatted = signature.formatted(
            tokens: [CodeToken(range: range, scope: .type)], colorScheme: .dark
        )
        let stringRange = try #require(Range(range, in: label))
        let active = try #require(Range(stringRange, in: formatted))
        #expect(String(formatted.characters) == label)
        #expect(formatted[active].font == .system(.body, design: .monospaced).bold())
        #expect(formatted[active].underlineStyle == .single)
        #expect(formatted[active].foregroundColor == Color(CodePalette.xcode.color(for: .type, in: .dark)))
        #expect(formatted[..<active.lowerBound].underlineStyle == nil)
    }

    @Test(arguments: [
        NSRange(location: NSNotFound, length: 1),
        NSRange(location: 1, length: Int.max),
        NSRange(location: 0, length: 0),
        NSRange(location: 2, length: 1),
    ])
    func invalidRangesAreIgnored(range: NSRange) {
        #expect(CodeSignature(label: "(👍)", activeParameter: range).activeParameter == nil)
    }

    @Test func acceptingCallableRequestsHelpWithoutACompletionQuery() async throws {
        let provider = SignatureProvider()
        let completer = CodeCompleter()
        completer.provider = provider
        let editor = CodeEditor(source: "gre")
        editor.focus()
        completer.focus(editor)
        completer.apply("greet(")
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 1 }
        #expect(provider.requests[0].source == "greet()")
        #expect(provider.requests[0].offset == 6)
        #expect(CodeCompletion.query(in: editor.source, at: try #require(editor.cursor)).isEmpty)
        provider.respond(0, with: CodeSignature(label: "(name: str)"))
        try await wait { completer.signature != nil }
        #expect(completer.signature?.current.label == "(name: str)")
        completer.reset()
    }

    @Test func caretMovementAndLeavingACallRefreshHelp() async throws {
        let provider = SignatureProvider()
        let completer = CodeCompleter()
        completer.provider = provider
        let editor = CodeEditor(source: "greet(1, 2)")
        editor.selection = NSRange(location: 6, length: 0)
        completer.focus(editor)
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 1 }
        provider.respond(0, with: CodeSignature(label: "(a: int, b: int)", activeParameter: NSRange(location: 1, length: 6)))
        try await wait { completer.signature != nil }
        editor.selection = NSRange(location: 9, length: 0)
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 2 }
        provider.respond(1, with: CodeSignature(label: "(a: int, b: int)", activeParameter: NSRange(location: 9, length: 6)))
        try await wait { completer.signature?.current.activeParameter?.location == 9 }
        editor.focus()
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 3 }
        provider.respond(2, with: nil)
        try await wait { completer.signature == nil }
        completer.reset()
    }

    @Test func lateResponsesCannotReplaceTheNewerRequest() async throws {
        let provider = SignatureProvider()
        let completer = CodeCompleter()
        completer.provider = provider
        let editor = CodeEditor(source: "greet(")
        editor.focus()
        completer.focus(editor)
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 1 }
        editor.source = "greet(1, "
        editor.focus()
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 2 }
        provider.respond(1, with: CodeSignature(label: "new"))
        try await wait { completer.signature?.current.label == "new" }
        provider.respond(0, with: CodeSignature(label: "old"))
        try await wait { provider.finished == 2 }
        #expect(completer.signature?.current.label == "new")
        completer.reset()
    }

    @Test(arguments: ["focus", "selection", "resign", "reset", "markdown"])
    func invalidationDiscardsPendingHelp(reason: String) async throws {
        let provider = SignatureProvider()
        let completer = CodeCompleter()
        completer.provider = provider
        let editor = CodeEditor(source: "greet(")
        editor.focus()
        completer.focus(editor)
        completer.update(editor, source: editor.source, cursor: editor.cursor)
        try await wait { provider.requests.count == 1 }
        switch reason {
        case "focus": completer.focus(CodeEditor(source: "other("))
        case "selection":
            editor.selection = NSRange(location: 0, length: 2)
            completer.update(editor, source: editor.source, cursor: editor.cursor)
        case "resign": completer.resign(editor)
        case "markdown": completer.focus(MarkdownEditor())
        default: completer.reset()
        }
        provider.respond(0, with: CodeSignature(label: "stale"))
        try await wait { provider.finished == 1 }
        #expect(completer.signature == nil)
        completer.reset()
    }

    private func wait(until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition())
    }
}

@MainActor
private final class SignatureProvider: CompletionProvider {
    struct Request {
        let source: String
        let offset: Int
        let continuation: CheckedContinuation<CodeSignatureHelp?, Never>
    }
    var requests: [Request] = []
    var finished = 0

    func completions(in editor: CodeEditor, source: String, cursor: String.Index) async -> [CodeSuggestion] { [] }

    func signatureHelp(in editor: CodeEditor, source: String, cursor: String.Index) async -> CodeSignatureHelp? {
        let result = await withCheckedContinuation { continuation in
            requests.append(Request(
                source: source, offset: cursor.utf16Offset(in: source), continuation: continuation
            ))
        }
        finished += 1
        return result
    }

    func respond(_ index: Int, with signature: CodeSignature?) {
        requests[index].continuation.resume(returning: signature.map(CodeSignatureHelp.init))
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
        // Only a line holding nothing but its indentation peels a level.
        ("    x|", "\n    "),
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
        // Two levels in, Enter peels one rather than dropping out of both.
        ("def f():\n    if x:\n        |", "\n    ", 5),
        ("def f():\n    if x:\n        |\nafter", "\n    ", 5),
        // The stop below a stray indent, as backspace does.
        ("      |", "\n    ", 5),
    ])
    func enterOnAnIndentedBlankLinePeelsALevel(marked: String, expected: String, caret: Int) {
        let (text, location) = split(marked)
        #expect(CodeIndent.newline(in: text, at: location)
                == .init(text: expected, caret: caret))
    }

    @Test(arguments: [
        // One level in, there is nothing to add: a plain newline, at column 0.
        "def f():\n    print(1)\n    |",
        "    |",
    ])
    func aBlankLineAtOneLevelFallsBackToAPlainNewline(marked: String) {
        let (text, location) = split(marked)
        #expect(CodeIndent.newline(in: text, at: location) == nil)
    }

    @Test func textAfterTheCaretKeepsTheIndent() {
        // Splitting a line is editing it, not leaving a block.
        let (text, location) = split("    |print(x)")
        #expect(CodeIndent.newline(in: text, at: location)
                == .init(text: "\n    ", caret: 5))
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

struct CodeSuggestionTests {
    @Test func iconsTakeTheHighlightersColorForWhatItColors() {
        #expect(CodeSuggestion.Kind.method.symbol == CodeSuggestion.Kind.function.symbol)
        #expect(CodeSuggestion.Kind.module.symbol == "curlybraces")
        #expect(CodeSuggestion.Kind.function.scope == .title)
        #expect(CodeSuggestion.Kind.class.scope == .titleClass)
        #expect(CodeSuggestion.Kind.keyword.scope == .keyword)
        #expect(CodeSuggestion.Kind.variable.scope == nil)
    }

    @MainActor
    @Test func suggestionsAreShownOnceByText() {
        let view = CompletionsView(completions: [
            CodeSuggestion(text: "print", kind: .function), CodeSuggestion(text: "print"), CodeSuggestion(text: "pow"),
        ]) { _ in }
        #expect(view.completions.map(\.text) == ["print", "pow"])
    }
}
