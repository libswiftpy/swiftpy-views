//
//  MarkdownEditor.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-09-28.
//

import SwiftUI
import SwiftPy
import SyntaxHighlight
import Observation

/// An editable, highlighted Markdown source view. Prose wraps, and none of the
/// code editor's gutter, indenting or pairing applies.
@Scriptable(base: .View)
@MainActor
@Observable
public final class MarkdownEditor {
    public var text: String
    public var isEditable: Bool

    internal private(set) var highlighted = Highlighted()

    /// Tokens with the text they were made from, as in ``CodeEditor``.
    internal struct Highlighted: Equatable {
        var text = ""
        var tokens: [CodeToken] = []
    }

    public init(text: String = "", isEditable: Bool = true) {
        self.text = text
        self.isEditable = isEditable
    }

    public func body() -> AnyView {
        AnyView(MarkdownEditorContent(model: self))
    }

    /// Re-tokenizes ``text`` as it changes, until the calling task is cancelled.
    internal func highlight() async {
        for await text in Observations({ self.text }) {
            let tokens = await CodeHighlighter.shared.tokens(for: text, language: "markdown")

            // `text` may have been edited while highlighting.
            guard text == self.text else { continue }

            highlighted = Highlighted(text: text, tokens: tokens)
        }
    }

    /// Colors `text` by `tokens`, which are UTF-16 ranges of its characters.
    internal static func color(
        _ text: inout AttributedString,
        by tokens: [CodeToken],
        in colorScheme: ColorScheme
    ) {
        let source = String(text.characters)
        text.foregroundColor = nil
        for token in tokens {
            guard let range = Range(token.range, in: source),
                  let attributedRange = Range(range, in: text)
            else { continue }
            text[attributedRange].foregroundColor = Color(
                platformColor: CodePalette.xcode.color(for: token.scope, in: colorScheme)
            )
        }
    }
}

public struct MarkdownEditorContent: View {
    @Bindable var model: MarkdownEditor

    // The editor's own copy: `model.text` is plain, this carries the colors.
    @State private var text = AttributedString()
    @State private var selection = AttributedTextSelection()
    @Environment(\.colorScheme) private var colorScheme

    public init(model: MarkdownEditor) {
        self.model = model
    }

    public var body: some View {
        TextEditor(text: $text, selection: $selection)
            // Colors are the only attributes: it is Markdown source, so bold
            // from the format menu would be styling nothing would save.
            .attributedTextFormattingDefinition(MarkdownSourceAttributes.self)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            // SwiftUI can't turn smart quotes and dashes off, and they would
            // corrupt the source; this keyboard doesn't apply them.
            .keyboardType(.asciiCapable)
            #endif
            .disabled(!model.isEditable)
            // Grows with its text; a window scrolls it with the rest.
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .scrollContentBackground(.hidden)
            .padding(4)
            .background(Color(platformColor: CodePalette.xcode.background(in: colorScheme)))
            .onChange(of: model.text, initial: true) {
                // Only from outside, such as Python setting it.
                guard String(text.characters) != model.text else { return }
                text = AttributedString(model.text)
                applyHighlight()
            }
            .onChange(of: text) {
                let characters = String(text.characters)
                if characters != model.text { model.text = characters }
            }
            .onChange(of: model.highlighted) { applyHighlight() }
            .onChange(of: colorScheme) { applyHighlight() }
            .task {
                await model.highlight()
            }
    }

    /// A highlight a keystroke behind is withheld rather than applied to text
    /// it wasn't made from.
    private func applyHighlight() {
        let highlighted = model.highlighted
        guard highlighted.text == String(text.characters) else { return }
        text.transform(updating: &selection) { text in
            MarkdownEditor.color(&text, by: highlighted.tokens, in: colorScheme)
        }
    }
}

private struct MarkdownSourceAttributes: AttributeScope {
    let foregroundColor: AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
}

extension Color {
    init(platformColor: CodeColor) {
        #if os(macOS)
        self.init(nsColor: platformColor)
        #else
        self.init(uiColor: platformColor)
        #endif
    }
}

#Preview {
    SwiftUI.ScrollView {
        MarkdownEditor(text: """
        # Title

        Some *prose* with `code` and a [link](https://example.com), long enough to wrap onto a second line.

        - one
        - two
        """)
        .body()
    }
}
