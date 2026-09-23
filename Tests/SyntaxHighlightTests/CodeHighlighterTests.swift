import Testing
import Foundation
@testable import SyntaxHighlight

struct CodeHighlighterTests {
    private let highlighter = CodeHighlighter()

    private func text(of token: CodeToken, in source: String) -> String {
        (source as NSString).substring(with: token.range)
    }

    @Test func scopesAnFStringSubstitutionApartFromTheString() async {
        let source = #"message = f"hello, {name}""#
        let tokens = await highlighter.tokens(for: source, language: "python")

        let subst = tokens.filter { $0.scope == .subst }
        #expect(subst.count == 1)
        #expect(subst.first.map { text(of: $0, in: source) } == "{name}")
        #expect(tokens.contains { $0.scope == .string })
    }

    @Test func keepsTheOffsetsOfSurroundingWhitespace() async {
        let source = "\n\n    print(1)\n"
        let tokens = await highlighter.tokens(for: source, language: "python")

        let builtIn = try? #require(tokens.first { $0.scope == .builtIn })
        #expect(builtIn.map { text(of: $0, in: source) } == "print")
        #expect(builtIn?.range.location == 6)
    }

    @Test func countsOffsetsInUTF16Units() async {
        let source = #"a = "👍b""#
        let tokens = await highlighter.tokens(for: source, language: "python")

        let string = tokens.first { $0.scope == .string }
        #expect(string.map { text(of: $0, in: source) } == #""👍b""#)
    }

    @Test func reportsAnUnbundledLanguageRatherThanFailing() async {
        #expect(await highlighter.outcome(for: "let x = 1;", language: "rust") == .unsupportedLanguage)
    }

    @Test func movesAnEmbeddedLanguageOntoTheOuterOffsets() async {
        let source = "<p>hi</p>\n<script>let x = 1;</script>\n"
        let tokens = await highlighter.tokens(for: source, language: "xml")

        // The closing tag is only at this offset if the script body advanced it.
        let names = tokens.filter { $0.scope == .name }
        #expect(names.map { text(of: $0, in: source) } == ["p", "p", "script", "script"])
        #expect(names.last?.range.location == 30)
    }

    @Test(arguments: ["bash", "diff", "json", "markdown", "plaintext", "python", "shell", "swift", "xml", "yaml"])
    func highlightsEveryBundledLanguage(_ language: String) async {
        let outcome = await highlighter.outcome(for: "a\nb: 1\n", language: language)

        guard case .tokens = outcome else {
            Issue.record("\(language): \(outcome)")
            return
        }
    }
}
