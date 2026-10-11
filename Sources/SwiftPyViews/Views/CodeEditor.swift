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

/// A span of code to underline, in the 1-based lines and columns a diagnostic
/// reports (columns in UTF-16, the end exclusive).
public struct CodeMarker: Equatable {
    public enum Style: Sendable {
        case underline
        /// The code's own colors, faded: what's unused or unreachable.
        case faded
    }

    public var line: Int
    public var column: Int
    public var endLine: Int
    public var endColumn: Int
    public var color: Color
    public var style: Style

    /// Width of one character of the editor's code, to place what points at it.
    @MainActor public static var characterAdvance: CGFloat { CodeTextView.characterAdvance }

    public init(line: Int, column: Int, endLine: Int, endColumn: Int, color: Color = .clear, style: Style = .underline) {
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
        self.color = color
        self.style = style
    }
}

/// An editable, syntax-highlighted Python source view.
@Scriptable(base: .View)
@MainActor
@Observable
public final class CodeEditor {
    public var source: String {
        didSet {
            if source != oldValue, marked.source == oldValue {
                marked = marked.carried(to: source)
            }
        }
    }
    public var isEditable: Bool
    /// Enter carries the indentation down, and backspace in a line's leading
    /// whitespace takes a level off.
    var autoIndent: Bool
    /// A bracket or quote brings its closer with it.
    var autoPairs: Bool
    var indentGuides: Bool

    internal var selection = NSRange(location: 0, length: 0)
    /// Until the text view takes the caret: it may not exist yet.
    internal var wantsFocus = false
    public internal(set) var isFocused = false
    internal private(set) var highlighted = Highlighted()
    internal private(set) var marked = Marked()

    /// Tokens with the source they were made from, so a highlight that is a
    /// keystroke behind can be recognised without comparing it to the buffer.
    internal struct Highlighted {
        var source = ""
        var tokens: [CodeToken] = []
    }

    /// Ranges with the source they were made for, so markers that are a
    /// keystroke behind aren't drawn over other text.
    internal struct Marked {
        var source = ""
        var marks: [CodeTextView.Mark] = []

        /// The faded marks the edit to `new` left alone, moved with the text
        /// after it, until the next markers. An underline goes: what it
        /// reported may be what's being fixed.
        func carried(to new: String) -> Marked {
            let old = Array(source.utf16), edited = Array(new.utf16)
            let prefix = zip(old, edited).prefix { $0 == $1 }.count
            let room = min(old.count, edited.count) - prefix
            let suffix = zip(old.reversed(), edited.reversed()).prefix(room).prefix { $0 == $1 }.count
            let shift = edited.count - old.count
            let kept: [CodeTextView.Mark] = marks.compactMap { mark in
                guard mark.style == .faded else { return nil }
                if NSMaxRange(mark.range) <= prefix { return mark }
                guard mark.range.location >= old.count - suffix else { return nil }
                return CodeTextView.Mark(
                    range: NSRange(location: mark.range.location + shift, length: mark.range.length),
                    color: mark.color, style: mark.style
                )
            }
            return Marked(source: new, marks: kept)
        }
    }

    public init(
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

    public func body() -> AnyView {
        AnyView(CodeEditorContent(model: self))
    }

    /// The width one line of source takes with its gutter, or nil when it spans
    /// several: a host can set controls beside code that leaves room for them.
    public var oneLineWidth: CGFloat? {
        guard !source.contains("\n") else { return nil }
        let advance = CodeTextView.characterAdvance
        // The one-digit gutter as `CodeEditorContent` sizes it, the code, and
        // room for the caret after it.
        return advance + 16 + CGFloat(source.count + 1) * advance
    }

    /// Puts the caret in the editor, at the end of its source.
    public func focus() {
        let end = (source as NSString).length
        selection = NSRange(location: end, length: 0)
        wantsFocus = true
    }

    /// The caret, or nil for a range selection, in the terms completion uses.
    internal var cursor: String.Index? {
        guard selection.length == 0,
              let range = Range(selection, in: source)
        else { return nil }
        return range.lowerBound
    }

    /// Drives `completer` while this editor holds the caret, until the calling
    /// task is cancelled. `Observations` yields its initial value, so taking
    /// the caret mid-identifier asks once straight away.
    internal func complete(with completer: CodeCompleter) async {
        completer.focus(self)
        defer { completer.resign(self) }

        for await (source, cursor) in Observations({ (self.source, self.cursor) }) {
            completer.update(self, source: source, cursor: cursor)
        }
    }

    /// Replaces the identifier at the caret with a chosen suggestion.
    internal func apply(_ completion: String) {
        guard let cursor else { return }

        let result = CodeCompletion.apply(
            completion,
            to: source,
            at: cursor,
            // The same indentation the Tab key puts in.
            indent: String(repeating: " ", count: CodeIndent.width)
        )
        source = result.source
        selection = NSRange(result.cursor..<result.cursor, in: result.source)
    }

    /// Underlines `markers`, found in `source`; they're withheld once the text
    /// is no longer that.
    public func setMarkers(_ markers: [CodeMarker], for source: String) {
        let text = source as NSString
        var lineStarts = [0]
        for index in 0..<text.length where text.character(at: index) == 0x0A {
            lineStarts.append(index + 1)
        }
        func offset(_ line: Int, _ column: Int) -> Int {
            guard line >= 1, line <= lineStarts.count else { return text.length }
            return min(lineStarts[line - 1] + max(column - 1, 0), text.length)
        }
        let marks: [CodeTextView.Mark] = markers.compactMap { marker in
            guard text.length > 0 else { return nil }
            var start = offset(marker.line, marker.column)
            var end = offset(marker.endLine, marker.endColumn)
            // A span with no width, or past the end, still marks a character.
            if start >= text.length { start = text.length - 1 }
            if end <= start { end = start + 1 }
            return CodeTextView.Mark(
                range: NSRange(location: start, length: end - start), color: marker.color, style: marker.style
            )
        }
        marked = Marked(source: source, marks: marks)
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

/// Zero-based rows of code shown as a diff: added ones green, removed ones red
/// and without a line number.
public struct CodeDiffLines: Equatable, Sendable {
    public var added: Set<Int>
    public var removed: Set<Int>

    public init(added: Set<Int> = [], removed: Set<Int> = []) {
        self.added = added
        self.removed = removed
    }
}

/// How far an editor's code is scrolled sideways, for a host that points at a
/// column. Published once, as `CodeScrollPositionKey`; the editor itself never
/// reads it, so scrolling doesn't redraw it.
@MainActor
@Observable
public final class CodeScrollPosition: Equatable {
    public internal(set) var offset: CGFloat = 0

    public nonisolated static func == (lhs: CodeScrollPosition, rhs: CodeScrollPosition) -> Bool {
        lhs === rhs
    }
}

public struct CodeScrollPositionKey: PreferenceKey {
    public static let defaultValue: CodeScrollPosition? = nil

    public static func reduce(value: inout CodeScrollPosition?, nextValue: () -> CodeScrollPosition?) {
        value = value ?? nextValue()
    }
}

public struct CodeEditorContent: View {
    @Bindable var model: CodeEditor
    private let diff: CodeDiffLines?
    private let gutterMark: (Int) -> AnyView?
    @State private var scrollPosition = CodeScrollPosition()

    // Reported by the text view once it has laid the code out, so the numbers
    // sit on the same grid as the lines instead of a grid of their own.
    @State private var lineHeight: CGFloat = 0
    @State private var scrollEdges = CodeTextView.ScrollEdges()
    @State private var isFocused = false
    @Environment(\.codeCompleter) private var completer
    @Environment(\.colorScheme) private var colorScheme
    // Read so the gutter is remeasured when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameter gutterMark: A view to show in a line's place in the gutter,
    ///   by 1-based line, such as a diagnostic's symbol; it takes the taps there.
    public init(
        model: CodeEditor,
        diff: CodeDiffLines? = nil,
        gutterMark: @escaping (Int) -> AnyView? = { _ in nil }
    ) {
        self.model = model
        self.diff = diff
        self.gutterMark = gutterMark
    }

    public var body: some View {
        let lineCount = model.source.count { $0 == "\n" } + 1
        let gutterWidth = CodeTextView.characterAdvance * CGFloat("\(lineCount)".count) + 16

        CodeTextView(
            text: model.source,
            // A stale highlight is withheld rather than applied to text it
            // wasn't made from.
            tokens: model.highlighted.source == model.source ? model.highlighted.tokens : nil,
            marks: model.marked.source == model.source ? model.marked.marks : [],
            colorScheme: colorScheme,
            isEditable: model.isEditable,
            editing: CodeEditing(
                autoIndent: model.autoIndent,
                autoPairs: model.autoPairs,
                indentGuides: model.indentGuides
            ),
            leadingInset: gutterWidth,
            selection: $model.selection,
            wantsFocus: model.wantsFocus,
            onTextChange: { model.source = $0 },
            onFocusChange: {
                isFocused = $0
                model.isFocused = $0
                if $0 { model.wantsFocus = false }
            },
            onLineHeight: { lineHeight = $0 },
            onScrollEdges: { scrollEdges = $0 },
            onScrollOffset: { [scrollPosition] in scrollPosition.offset = $0 }
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
                lineNumbers(lineCount, gutterWidth: gutterWidth)
                    .frame(width: gutterWidth, alignment: .topTrailing)
                    .frame(maxHeight: .infinity, alignment: .top)
                    // Glass only while there is code behind it to separate from.
                    .background(alignment: .topLeading) {
                        if scrollEdges.leading {
                            Color.clear
                                .glassBackground(in: .rect)
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                    }
                    .animation(.default, value: scrollEdges.leading)
            }
        }
        .preference(key: CodeScrollPositionKey.self, value: scrollPosition)
        // Behind the code, the full width of the card.
        .backgroundPreferenceValue(LineNumberBoundsKey.self) { anchors in
            if let diff {
                GeometryReader { geometry in
                    ForEach(Array(diff.added.union(diff.removed)), id: \.self) { row in
                        if let anchor = anchors[row + 1] {
                            let bounds = geometry[anchor]
                            (diff.removed.contains(row) ? Color.red : Color.green)
                                .opacity(0.25)
                                .frame(width: geometry.size.width, height: bounds.height)
                                .position(x: geometry.size.width / 2, y: bounds.midY)
                        }
                    }
                }
            }
        }
        .background(Color(CodePalette.xcode.background(in: colorScheme)))
        // A window hands its whole space over; a card proposes no height and
        // the editor keeps the code's own.
        .fillsAvailableSpace()
        .task {
            await model.highlight()
        }
        // Not while read-only: AppKit focuses a selectable text view too.
        .task(id: isFocused && model.isEditable) {
            guard isFocused, model.isEditable, let completer else { return }
            await model.complete(with: completer)
        }
    }

    /// Each row's number; in a diff, removed rows have none and the rest are
    /// numbered as the new code.
    private func lineLabels(_ lines: Int) -> [String] {
        var number = 0
        return (0..<lines).map { row in
            if diff?.removed.contains(row) == true { return "" }
            number += 1
            return "\(number)"
        }
    }

    private func lineNumbers(_ lines: Int, gutterWidth: CGFloat) -> some View {
        let labels = lineLabels(lines)
        return SwiftUI.VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lines, id: \.self) { line in
                let mark = gutterMark(line)
                // A mark keeps the number's place, so the line's bounds stay.
                SwiftUI.Text(labels[line - 1])
                    .opacity(mark == nil ? 1 : 0)
                    .frame(height: lineHeight)
                    // The numbers are decoration: taps belong to the code.
                    .allowsHitTesting(false)
                    .anchorPreference(key: LineNumberBoundsKey.self, value: .bounds) { anchor in
                        [line: anchor]
                    }
                    // Centered on the number, which is centered in the gutter.
                    .overlay {
                        if let mark {
                            mark
                                .frame(width: gutterWidth, height: lineHeight)
                                // A little taller to tap than the line.
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                                .padding(.vertical, -6)
                        }
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
