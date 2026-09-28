import Testing
import SwiftUI
import SyntaxHighlight
@testable import SwiftPyViews

@MainActor
struct MarkdownEditorTests {
    /// The characters each colored run covers.
    private func coloredRuns(_ text: AttributedString) -> [String] {
        text.runs.compactMap { run in
            run.foregroundColor == nil ? nil : String(text[run.range].characters)
        }
    }

    @Test func tokensColorTheirCharactersOnly() {
        var text = AttributedString("# Title\nprose")
        let heading = CodeToken(range: NSRange(location: 0, length: 7), scope: .section)

        MarkdownEditor.color(&text, by: [heading], in: .light)

        #expect(coloredRuns(text) == ["# Title"])
    }

    @Test func aTokenPastAMultiByteCharacterLandsOnItsCharacters() {
        // The thumb is two UTF-16 units, so `code` starts at 4, not 3.
        var text = AttributedString("👍 `code`")
        let code = CodeToken(range: NSRange(location: 3, length: 6), scope: .code)

        MarkdownEditor.color(&text, by: [code], in: .light)

        #expect(coloredRuns(text) == ["`code`"])
    }

    @Test func recoloringClearsTheOldColors() {
        var text = AttributedString("# Title")
        MarkdownEditor.color(&text, by: [CodeToken(range: NSRange(location: 0, length: 7), scope: .section)], in: .light)

        MarkdownEditor.color(&text, by: [], in: .light)

        #expect(coloredRuns(text).isEmpty)
    }

    @Test func aHeadingIsHighlightedAsASection() async throws {
        let editor = MarkdownEditor(text: "# Title")
        let task = Task { await editor.highlight() }
        defer { task.cancel() }

        var waited = 0
        while editor.highlighted.text != editor.text, waited < 200 {
            try await Task.sleep(for: .milliseconds(10))
            waited += 1
        }

        #expect(editor.highlighted.tokens.contains { $0.scope == .section })
    }
}
