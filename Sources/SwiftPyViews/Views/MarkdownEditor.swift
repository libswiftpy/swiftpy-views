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
    /// The zero-based line of the caret while focused; nil for a range.
    public internal(set) var caretLine: Int?

    public var isCaretOnEmptyLine: Bool {
        guard let caretLine else { return false }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return caretLine < lines.count && lines[caretLine].allSatisfy(\.isWhitespace)
    }

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

    /// The zero-based line of an insertion point in `text`, nil for a range.
    internal static func line(of selection: AttributedTextSelection, in text: AttributedString) -> Int? {
        guard case let .insertionPoint(index) = selection.indices(in: text) else { return nil }
        return text.characters[..<index].count { $0 == "\n" }
    }

    /// Character offsets as a range of `text`, or nil past its end.
    internal static func range(_ offsets: Range<Int>, in text: AttributedString) -> Range<AttributedString.Index>? {
        let characters = text.characters
        guard offsets.lowerBound >= 0, offsets.upperBound <= characters.count else { return nil }
        let lower = characters.index(characters.startIndex, offsetBy: offsets.lowerBound)
        let upper = characters.index(lower, offsetBy: offsets.count)
        return lower..<upper
    }

    /// Where zero-based `line` ends in `text`, before its newline; the text's
    /// end past the last line.
    internal static func endIndex(ofLine line: Int, in text: AttributedString) -> AttributedString.Index {
        var start = text.startIndex
        for _ in 0..<line {
            guard let newline = text.characters[start...].firstIndex(of: "\n") else {
                return text.endIndex
            }
            start = text.characters.index(after: newline)
        }
        return text.characters[start...].firstIndex(of: "\n") ?? text.endIndex
    }
}

public struct MarkdownEditorContent: View {
    @Bindable var model: MarkdownEditor
    private let caretLine: Int?
    private let initialSelection: Range<Int>?
    private let onEditingChanged: (Bool) -> Void

    // The editor's own copy: `model.text` is plain, this carries the colors.
    @State private var text = AttributedString()
    @State private var selection = AttributedTextSelection()
    @State private var hasPlacedCaret = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.codeCompleter) private var completer

    /// caretLine: Focuses the editor, with the caret at the end of this
    /// zero-based line.
    /// selection: Characters of the text to select instead, once focused.
    public init(
        model: MarkdownEditor,
        caretLine: Int? = nil,
        selection: Range<Int>? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.caretLine = caretLine
        self.initialSelection = selection
        self.onEditingChanged = onEditingChanged
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
            .focused($isFocused)
            .onAppear { if caretLine != nil { isFocused = true } }
            .onChange(of: isFocused) { _, isFocused in
                if isFocused {
                    completer?.focus(model)
                } else {
                    completer?.resign(model)
                }
                updateCaretLine()
                onEditingChanged(isFocused)
            }
            .onChange(of: selection) { updateCaretLine() }
            .onDisappear { completer?.resign(model) }
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

                if let caretLine, !hasPlacedCaret {
                    hasPlacedCaret = true
                    if let range = initialSelection.flatMap({ MarkdownEditor.range($0, in: text) }) {
                        selection = AttributedTextSelection(range: range)
                    } else {
                        selection = AttributedTextSelection(
                            insertionPoint: MarkdownEditor.endIndex(ofLine: caretLine, in: text)
                        )
                    }
                }
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

    private func updateCaretLine() {
        let line = isFocused ? MarkdownEditor.line(of: selection, in: text) : nil
        if model.caretLine != line { model.caretLine = line }
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
