//
//  CodeEditor.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-09-23.
//

import SwiftUI
import SwiftPy
import SyntaxHighlight
import Observation

/// An editable, syntax-highlighted Python source view.
@Scriptable(base: .View)
@MainActor
@Observable
final class CodeEditor {
    var source: String
    var isEditable: Bool
    /// Enter carries the indentation down, and backspace in a line's leading
    /// whitespace takes a level off.
    var autoIndent: Bool
    /// A bracket or quote brings its closer with it.
    var autoPairs: Bool
    var indentGuides: Bool

    internal var selection = NSRange(location: 0, length: 0)
    internal private(set) var highlighted = Highlighted()

    /// Tokens with the source they were made from, so a highlight that is a
    /// keystroke behind can be recognised without comparing it to the buffer.
    internal struct Highlighted {
        var source = ""
        var tokens: [CodeToken] = []
    }

    init(
        source: String = "",
        isEditable: Bool = true,
        autoIndent: Bool = true,
        autoPairs: Bool = true,
        indentGuides: Bool = true
    ) {
        self.source = source
        self.isEditable = isEditable
        self.autoIndent = autoIndent
        self.autoPairs = autoPairs
        self.indentGuides = indentGuides
    }

    func body() -> AnyView {
        AnyView(CodeEditorContent(model: self))
    }

    /// The caret, or nil for a range selection, in the terms completion uses.
    internal var cursor: String.Index? {
        guard selection.length == 0,
              let range = Range(selection, in: source)
        else { return nil }
        return range.lowerBound
    }

    /// Re-tokenizes ``source`` as it changes, until the calling task is cancelled.
    /// The scopes don't depend on the color scheme; the palette resolves that
    /// where the text is drawn.
    internal func highlight() async {
        for await source in Observations({ self.source }) {
            let tokens = await CodeHighlighter.shared.tokens(for: source, language: "python")

            // `source` may have been edited while highlighting.
            guard source == self.source else { continue }

            highlighted = Highlighted(source: source, tokens: tokens)
        }
    }
}

private struct CodeEditorContent: View {
    @Bindable var model: CodeEditor

    // Reported by the text view once it has laid the code out, so the numbers
    // sit on the same grid as the lines instead of a grid of their own.
    @State private var lineHeight: CGFloat = 0
    @State private var scrollEdges = CodeTextView.ScrollEdges()
    @Environment(\.colorScheme) private var colorScheme
    // Read so the gutter is remeasured when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let lineCount = model.source.count { $0 == "\n" } + 1
        let gutterWidth = CodeTextView.characterAdvance * CGFloat("\(lineCount)".count) + 16

        CodeTextView(
            text: model.source,
            // A stale highlight is withheld rather than applied to text it
            // wasn't made from.
            tokens: model.highlighted.source == model.source ? model.highlighted.tokens : nil,
            colorScheme: colorScheme,
            isEditable: model.isEditable,
            editing: CodeEditing(
                autoIndent: model.autoIndent,
                autoPairs: model.autoPairs,
                indentGuides: model.indentGuides
            ),
            leadingInset: gutterWidth,
            selection: $model.selection,
            onTextChange: { model.source = $0 },
            onLineHeight: { lineHeight = $0 },
            onScrollEdges: { scrollEdges = $0 }
        )
        // A shadow where the code carries on past the trailing edge, to say so.
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 8)
            .opacity(scrollEdges.trailing ? 1 : 0)
            .animation(.default, value: scrollEdges.trailing)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if lineHeight > 0 {
                lineNumbers(lineCount)
                    .frame(width: gutterWidth, alignment: .topTrailing)
                    .frame(maxHeight: .infinity, alignment: .top)
                    // Glass only while there is code behind it to separate from.
                    .background(alignment: .topLeading) {
                        if scrollEdges.leading {
                            Color.clear
                                .glassBackground(in: .rect)
                                .transition(.opacity)
                        }
                    }
                    .animation(.default, value: scrollEdges.leading)
                    // The gutter is decoration: taps belong to the editor underneath.
                    .allowsHitTesting(false)
            }
        }
        .background(Color(CodePalette.xcode.background(in: colorScheme)))
        // A window hands its whole space over; a card proposes no height and
        // the editor keeps the code's own.
        .fillsAvailableSpace()
        .task {
            await model.highlight()
        }
    }

    private func lineNumbers(_ lines: Int) -> some View {
        SwiftUI.VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lines, id: \.self) { line in
                SwiftUI.Text("\(line)")
                    .frame(height: lineHeight)
                    .anchorPreference(key: LineNumberBoundsKey.self, value: .bounds) { anchor in
                        [line: anchor]
                    }
            }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.tertiary)
        .padding(.top, CodeTextView.verticalInset)
        .padding(.trailing, 8)
    }
}

#Preview {
    SwiftUI.ScrollView {
        CodeEditor(
            source: """
            def greet(name):
                message = f'a much longer line than the ones around it, {name}'
                print(message)
            """
        )
        .body()
    }
}
