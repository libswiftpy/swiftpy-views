//
//  CodeTextView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-09-23.
//

import SwiftUI
import SyntaxHighlight

#if os(macOS)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#else
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#endif

/// The editor's habits, each one something a reader might not want.
struct CodeEditing: Equatable {
    var autoIndent = true
    var autoPairs = true
    var indentGuides = true
}

/// The platform's text view, laid out as code: no wrapping, scrolled
/// horizontally, sized to its content. `TextEditor` does none of those.
@MainActor
struct CodeTextView {
    /// Padding above and below the text; the gutter aligns to it.
    static let verticalInset: CGFloat = 8

    let text: String
    /// Nil while the tokens belong to text other than ``text``.
    let tokens: [CodeToken]?
    let colorScheme: ColorScheme
    let isEditable: Bool
    let editing: CodeEditing
    /// Kept clear on the leading edge for the line-number gutter.
    let leadingInset: CGFloat
    @Binding var selection: NSRange
    let onTextChange: (String) -> Void
    let onLineHeight: (CGFloat) -> Void
    let onScrollEdges: (ScrollEdges) -> Void

    /// Which edges have code beyond them, so the gutter's glass and the
    /// trailing shadow only appear when there is something behind them.
    struct ScrollEdges: Equatable {
        var leading = false
        var trailing = false
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: CodeTextView
        // Set while the view is written to, so the delegate callbacks that
        // provokes aren't read back as edits.
        fileprivate var isApplyingUpdate = false
        fileprivate var lineHeight: CGFloat = 0
        fileprivate var scrollEdges = ScrollEdges()
        fileprivate var codeWidth: CGFloat = 0
        /// What the last measurement was of, so the container isn't unbounded
        /// and re-measured on updates that changed neither.
        fileprivate var measured: (text: String, leadingInset: CGFloat, font: PlatformFont)?

        init(_ parent: CodeTextView) {
            self.parent = parent
        }
    }
}

// MARK: - Metrics

extension CodeTextView {
    /// Width of one character in the editor's font, for the gutter.
    static var characterAdvance: CGFloat {
        NSAttributedString(string: "0", attributes: [.font: font])
            .size()
            .width
    }

    fileprivate static var font: PlatformFont {
        #if os(macOS)
        NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        #else
        UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        #endif
    }

    fileprivate static var textAttributes: [NSAttributedString.Key: Any] {
        #if os(macOS)
        [.font: font, .foregroundColor: PlatformColor.labelColor]
        #else
        [.font: font, .foregroundColor: PlatformColor.label]
        #endif
    }

    /// An unbounded text container, which is what stops it from wrapping.
    fileprivate static let unboundedSize = CGSize(width: 1_000_000, height: 1_000_000)
}

private extension NSTextLayoutManager {
    var codeTextStorage: NSTextStorage? {
        (textContentManager as? NSTextContentStorage)?.textStorage
    }

    /// The laid-out text's extent and the height of its first line.
    /// `.ensuresExtraLineFragment` counts the empty line after a trailing
    /// newline, which `usageBoundsForTextContainer` leaves out.
    func contentMetrics() -> (height: CGFloat, width: CGFloat, lineHeight: CGFloat) {
        var height: CGFloat = 0
        var width: CGFloat = 0
        var lineHeight: CGFloat = 0

        enumerateTextLayoutFragments(
            from: nil,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            height = max(height, frame.maxY)
            width = max(width, frame.maxX)
            if lineHeight == 0 { lineHeight = frame.height }
            return true
        }

        return (height, width, lineHeight)
    }
}

private extension CodeTextView {
    /// Colors the text in place. Assigning an attributed string instead would
    /// reset the selection, the scroll offset and the undo stack.
    func applyHighlight(to storage: NSTextStorage) {
        // The tokens can be a keystroke behind what is on screen; leaving the
        // stale colors alone reads better than flattening the whole text.
        guard let tokens else { return }

        let length = storage.length
        storage.beginEditing()
        storage.setAttributes(Self.textAttributes, range: NSRange(location: 0, length: length))
        for token in tokens where NSMaxRange(token.range) <= length {
            storage.addAttribute(
                .foregroundColor,
                value: CodePalette.xcode.color(for: token.scope, in: colorScheme),
                range: token.range
            )
        }
        storage.endEditing()
    }

    func reportLineHeight(_ lineHeight: CGFloat, to coordinator: Coordinator) {
        guard lineHeight > 0, lineHeight != coordinator.lineHeight else { return }
        coordinator.lineHeight = lineHeight

        // Reported out of the layout pass that measured it.
        let report = onLineHeight
        Task { @MainActor in report(lineHeight) }
    }

    func reportScroll(
        offset: CGFloat,
        visibleWidth: CGFloat,
        contentWidth: CGFloat,
        to coordinator: Coordinator
    ) {
        guard visibleWidth > 0 else { return }

        let edges = ScrollEdges(
            leading: offset > 0.5,
            trailing: offset + visibleWidth < contentWidth - 0.5
        )
        guard edges != coordinator.scrollEdges else { return }
        coordinator.scrollEdges = edges

        // Reported out of the layout pass that measured it.
        let report = onScrollEdges
        Task { @MainActor in report(edges) }
    }

    /// The code's own height, or the height on offer: a window hands the
    /// editor its whole space, a card proposes nothing and gets the content.
    static func height(_ contentHeight: CGFloat, proposal: ProposedViewSize) -> CGFloat {
        guard let proposed = proposal.height, proposed.isFinite else {
            return contentHeight
        }
        return proposed
    }

    static func width(_ proposal: ProposedViewSize, contentWidth: CGFloat) -> CGFloat {
        guard let width = proposal.width, width.isFinite else { return contentWidth }
        return width
    }
}

// MARK: - Indentation

/// The editing rules both platforms' delegates share, as pure functions over
/// UTF-16 offsets so they can be tested without a view.
enum CodeIndent {
    /// Spaces per indentation, which is also the guides' spacing.
    static let width = 4

    /// Text to insert, and where in it the caret lands.
    struct Insertion: Equatable {
        var text: String
        var caret: Int
    }

    /// What a newline at `location` should insert, or nil for a plain one the
    /// platform can put in itself.
    static func newline(in text: NSString, at location: Int) -> Insertion? {
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        let head = text.substring(with: NSRange(location: lineStart, length: location - lineStart))
        let indent = String(head.prefix { $0 == " " })
        let level = String(repeating: " ", count: width)

        // Inside a bracket, the pair opens out and the caret sits between.
        if CodePairs.isInsideBrackets(in: text, at: location) {
            let opened = "\n" + indent + level
            return Insertion(text: opened + "\n" + indent, caret: opened.utf16.count)
        }

        // A trailing colon opens a block, whatever follows it on the line.
        let opensBlock = head.reversed().drop(while: { $0 == " " || $0 == "\t" }).first == ":"
        guard opensBlock || !indent.isEmpty else { return nil }

        let inserted = "\n" + indent + (opensBlock ? level : "")
        return Insertion(text: inserted, caret: inserted.utf16.count)
    }

    /// The range a backspace should take out when the caret sits in a line's
    /// leading whitespace, or nil to delete as usual. The line drops to the
    /// previous indentation level and the caret lands on the text, so the
    /// spaces past the caret go too.
    static func outdent(in text: NSString, at location: Int) -> NSRange? {
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        guard location > lineStart else { return nil }

        let head = text.substring(with: NSRange(location: lineStart, length: location - lineStart))
        guard head.allSatisfy({ $0 == " " }) else { return nil }

        // The whole run of spaces, which reaches past the caret.
        var indent = location - lineStart
        while lineStart + indent < text.length,
              text.character(at: lineStart + indent) == 0x20 {
            indent += 1
        }

        // Down to the previous stop, which also tidies a stray odd indent.
        let outdented = ((indent - 1) / width) * width
        return NSRange(location: lineStart + outdented, length: indent - outdented)
    }
}

/// What typing a bracket or quote should do beyond inserting it.
enum CodePairEdit: Equatable {
    /// Insert the typed character with `closer` behind it, caret between.
    case close(String)
    /// Step over the closer that is already there rather than adding another.
    case skip
}

/// Bracket and quote pairing. Pure, like ``CodeIndent``, and over UTF-16 units
/// so an emoji next to the caret can't be split.
enum CodePairs {
    static let byOpener: [unichar: unichar] = [
        0x28: 0x29,  // ( )
        0x5B: 0x5D,  // [ ]
        0x7B: 0x7D,  // { }
        0x22: 0x22,  // " "
        0x27: 0x27,  // ' '
    ]
    private static let closers: Set<unichar> = [0x29, 0x5D, 0x7D, 0x22, 0x27]
    private static let quotes: Set<unichar> = [0x22, 0x27]

    static func edit(typing input: String, in text: NSString, at location: Int) -> CodePairEdit? {
        let units = Array(input.utf16)
        guard units.count == 1, let typed = units.first else { return nil }

        let next: unichar? = location < text.length ? text.character(at: location) : nil

        // Stepping over comes first, so a quote ends the string it opened
        // instead of starting a new one.
        if closers.contains(typed), next == typed { return .skip }

        guard let closer = byOpener[typed] else { return nil }

        // Inside a string or a comment nothing is code, so nothing pairs —
        // an apostrophe in prose, or a paren in a message.
        guard context(in: text, at: location) == .code else { return nil }

        if quotes.contains(typed), location > 0 {
            let previous = text.character(at: location - 1)
            if previous == typed { return nil }
            // A word before a quote makes it an apostrophe — unless the word
            // is a string prefix, where `f"` is exactly what was meant.
            if isWord(previous), !isStringPrefix(in: text, endingAt: location) {
                return nil
            }
        }

        // Not where the closer would land against a word.
        if let next, isWord(next) { return nil }

        return .close(String(utf16CodeUnits: [closer], count: 1))
    }

    /// The empty pair around the caret, which a backspace takes out whole: the
    /// closer went in unasked, so one keystroke undoes the one that added it.
    static func emptyPair(in text: NSString, at location: Int) -> NSRange? {
        guard location > 0, location < text.length,
              let closer = byOpener[text.character(at: location - 1)],
              text.character(at: location) == closer
        else { return nil }
        return NSRange(location: location - 1, length: 2)
    }

    /// Whether the caret sits in an empty bracket pair. Quotes are left out: a
    /// newline inside one is a syntax error, not a block.
    static func isInsideBrackets(in text: NSString, at location: Int) -> Bool {
        guard let pair = emptyPair(in: text, at: location) else { return false }
        return !quotes.contains(text.character(at: pair.location))
    }

    /// Where the caret sits, as far as pairing cares.
    enum Context: Equatable {
        case code
        case string(quote: unichar)
        case comment
    }

    /// Read from the start of the caret's line, so a triple-quoted string
    /// spanning lines reads as code after its first one.
    static func context(in text: NSString, at location: Int) -> Context {
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        var quote: unichar?
        var index = lineStart

        while index < location {
            let unit = text.character(at: index)
            if let open = quote {
                // A backslash takes the next character with it, so an escaped
                // quote doesn't close the string.
                if unit == 0x5C { index += 2; continue }
                if unit == open { quote = nil }
            } else if quotes.contains(unit) {
                quote = unit
            } else if unit == 0x23 {
                return .comment
            }
            index += 1
        }

        return quote.map { .string(quote: $0) } ?? .code
    }

    /// Whether the word ending at `location` is a Python string prefix.
    private static func isStringPrefix(in text: NSString, endingAt location: Int) -> Bool {
        var start = location
        while start > 0, isWord(text.character(at: start - 1)) { start -= 1 }
        let word = text.substring(with: NSRange(location: start, length: location - start))
        return ["r", "u", "f", "fr", "rf", "b", "br", "rb"].contains(word.lowercased())
    }

    /// Anything past ASCII counts: identifiers hold it, and so does prose.
    private static func isWord(_ unit: unichar) -> Bool {
        unit > 0x7F
            || (unit >= 0x30 && unit <= 0x39)
            || (unit >= 0x41 && unit <= 0x5A)
            || (unit >= 0x61 && unit <= 0x7A)
            || unit == 0x5F
    }
}

// MARK: - Indent guides

private var currentDrawingContext: CGContext? {
    #if os(macOS)
    NSGraphicsContext.current?.cgContext
    #else
    UIGraphicsGetCurrentContext()
    #endif
}

/// A hairline at each indentation boundary inside a line's leading spaces, so
/// nesting reads without counting columns. Eight spaces gets one line, between
/// the two indentations. Drawn where the leading whitespace is, so it never
/// crosses a glyph.
@MainActor
private func drawIndentGuides(
    text: String,
    layoutManager: NSTextLayoutManager,
    inset: CGSize,
    color: PlatformColor,
    in clip: CGRect
) {
    guard let context = currentDrawingContext else { return }

    let advance = CodeTextView.characterAdvance
    let indent = CodeIndent.width
    let lines = text.components(separatedBy: "\n")
    var index = 0
    // The last fragment swallows the empty line after a trailing newline, so
    // its frame is two lines tall. Every line is the height of the first.
    var lineHeight: CGFloat = 0

    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(1)

    layoutManager.enumerateTextLayoutFragments(from: nil, options: [.ensuresLayout]) { fragment in
        defer { index += 1 }
        guard index < lines.count else { return false }

        let frame = fragment.layoutFragmentFrame
        if lineHeight == 0 { lineHeight = frame.height }
        let top = frame.minY + inset.height
        let height = min(frame.height, lineHeight)
        guard top < clip.maxY, top + height > clip.minY else { return true }

        let levels = lines[index].prefix { $0 == " " }.count / indent
        guard levels > 1 else { return true }

        for level in 1..<levels {
            // Half a point off the pixel grid, or the hairline blurs.
            let x = (inset.width + CGFloat(level * indent) * advance).rounded() + 0.5
            context.move(to: CGPoint(x: x, y: top))
            context.addLine(to: CGPoint(x: x, y: top + height))
        }
        return true
    }

    context.strokePath()
    context.restoreGState()
}

// MARK: - iOS, visionOS

#if !os(macOS)
/// A `UITextView` in a scroll view of our own. Its `contentSize.width` always
/// tracks its bounds, so on its own it can only ever wrap — it has no way to
/// scroll a long line sideways. Here it is laid out at the code's full width
/// and the scroll view around it does the scrolling.
///
/// UIKit reveals the caret through the responder chain, as it does for any text
/// input inside a scroll view, but its rect at the end of a line reaches the far
/// edge of the container and throws the view to the right — on an empty line,
/// after the last character, and again on every layout pass while scrolling.
/// Those reveals are refused and the caret is followed here instead.
/// Draws the indent guides under the text. TextKit 2 puts each line in a
/// fragment subview, so the view's own drawing lands behind them.
final class CodeUITextView: UITextView {
    var showsIndentGuides = true {
        didSet { if showsIndentGuides != oldValue { setNeedsDisplay() } }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard showsIndentGuides, let layoutManager = textLayoutManager else { return }
        drawIndentGuides(
            text: text,
            layoutManager: layoutManager,
            inset: CGSize(width: textContainerInset.left, height: textContainerInset.top),
            color: .separator,
            in: rect
        )
    }
}

final class CodeScrollView: UIScrollView {
    let textView = CodeUITextView(usingTextLayoutManager: true)

    /// What the code needs, measured when it changes.
    var codeSize: CGSize = .zero {
        didSet { if codeSize != oldValue { setNeedsLayout() } }
    }

    /// Called once the content size has settled: editing a line past the
    /// trailing edge changes what is off screen without scrolling.
    var onLayout: (@MainActor () -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {}

    /// Follows the caret, only when it isn't already visible, so that nothing
    /// else moving the view can be fought over.
    func scrollToCaret() {
        guard let range = textView.selectedTextRange else { return }

        let caret = textView.convert(textView.caretRect(for: range.end), to: self)
        guard !caret.isNull, caret.maxX.isFinite else { return }

        // A couple of columns of context, so the caret isn't against the edge.
        let margin = CodeTextView.characterAdvance * 2
        // The gutter sits over the leading edge, so the code is only visible
        // past it — scrolling the caret to the edge would leave it hidden.
        let gutter = textView.textContainerInset.left
        let furthest = max(0, contentSize.width - bounds.width)
        var x = contentOffset.x

        if caret.minX - margin < contentOffset.x + gutter {
            x = min(max(0, caret.minX - margin - gutter), furthest)
        } else if caret.maxX + margin > contentOffset.x + bounds.width {
            x = min(max(0, caret.maxX + margin - bounds.width), furthest)
        }

        guard abs(x - contentOffset.x) > 0.5 else { return }
        contentOffset.x = x
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // At least the visible size, so a tap anywhere lands in the text.
        let size = CGSize(
            width: max(codeSize.width, bounds.width),
            height: max(codeSize.height, bounds.height)
        )
        if textView.frame.size != size {
            textView.frame = CGRect(origin: .zero, size: size)
        }
        if contentSize != size {
            contentSize = size
        }

        // The container must not follow the frame, or the lines wrap.
        let inset = textView.textContainerInset
        let width = size.width - inset.left - inset.right
        if abs(textView.textContainer.size.width - width) > 0.5 {
            textView.textContainer.size = CGSize(width: width, height: CodeTextView.unboundedSize.height)
        }

        onLayout?()
    }
}

extension CodeTextView: UIViewRepresentable {
    func makeUIView(context: Context) -> CodeScrollView {
        let scrollView = CodeScrollView()
        let textView = scrollView.textView
        assert(textView.textLayoutManager != nil, "fell back to TextKit 1")

        textView.delegate = context.coordinator
        scrollView.delegate = context.coordinator
        scrollView.onLayout = { [weak scrollView, coordinator = context.coordinator] in
            guard let scrollView else { return }
            coordinator.reportScroll(of: scrollView)
        }
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        textView.backgroundColor = .clear
        // The highlight sets the font too, but it lands later — and the layout
        // is measured before it does.
        textView.font = Self.font
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = false
        textView.textContainer.heightTracksTextView = false
        textView.textContainer.lineBreakMode = .byClipping
        textView.textContainer.size = Self.unboundedSize

        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.inlinePredictionType = .no
        textView.writingToolsBehavior = .none
        textView.keyboardType = .asciiCapable

        return scrollView
    }

    func updateUIView(_ scrollView: CodeScrollView, context: Context) {
        let textView = scrollView.textView
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isApplyingUpdate = true
        defer { coordinator.isApplyingUpdate = false }

        textView.isEditable = isEditable
        textView.showsIndentGuides = editing.indentGuides
        if textView.font != Self.font {
            textView.font = Self.font
        }
        // A view inset rather than the container's line padding, which TextKit 2
        // only applies to the fragments it lays out after the change.
        let insets = UIEdgeInsets(
            top: Self.verticalInset, left: leadingInset,
            bottom: Self.verticalInset, right: 0
        )
        if textView.textContainerInset != insets {
            textView.textContainerInset = insets
            textView.setNeedsDisplay()
        }

        if textView.text != text {
            textView.text = text
            textView.setNeedsDisplay()
        }
        if let storage = textView.textLayoutManager?.codeTextStorage {
            applyHighlight(to: storage)
        }
        textView.typingAttributes = Self.textAttributes

        if textView.selectedRange != selection,
           selection.upperBound <= (textView.text as NSString).length {
            textView.selectedRange = selection
        }

        if coordinator.measured?.text != text
            || coordinator.measured?.leadingInset != leadingInset
            || coordinator.measured?.font != Self.font {
            coordinator.measured = (text, leadingInset, Self.font)
            measure(scrollView, coordinator: coordinator)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CodeScrollView, context: Context) -> CGSize? {
        let code = uiView.codeSize

        return CGSize(
            width: Self.width(proposal, contentWidth: code.width),
            height: Self.height(code.height, proposal: proposal)
        )
    }

    /// Measures the code unwrapped, which is the only way to learn its width.
    private func measure(_ scrollView: CodeScrollView, coordinator: Coordinator) {
        let textView = scrollView.textView
        guard let layoutManager = textView.textLayoutManager else { return }

        textView.textContainer.size = Self.unboundedSize
        let metrics = layoutManager.contentMetrics()
        let inset = textView.textContainerInset

        scrollView.codeSize = CGSize(
            // Room for the caret past the last character of the longest line.
            width: metrics.width + inset.left + inset.right + Self.characterAdvance,
            height: metrics.height + inset.top + inset.bottom
        )

        reportLineHeight(metrics.lineHeight, to: coordinator)
    }
}

extension CodeTextView.Coordinator: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingUpdate else { return }
        // Typing leaves the view already holding the text, so the update pass
        // sees nothing to write and never invalidates the guides.
        textView.setNeedsDisplay()
        parent.onTextChange(textView.text)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isApplyingUpdate else { return }
        parent.selection = textView.selectedRange
        (textView.superview as? CodeScrollView)?.scrollToCaret()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        reportScroll(of: scrollView)
    }

    /// More than the one character behind the caret: an empty pair, or a
    /// whole indentation level.
    fileprivate func backspaceRange(at location: Int, in source: NSString) -> NSRange? {
        if parent.editing.autoPairs,
           let pair = CodePairs.emptyPair(in: source, at: location) {
            return pair
        }
        guard parent.editing.autoIndent else { return nil }
        return CodeIndent.outdent(in: source, at: location)
    }

    fileprivate func reportScroll(of scrollView: UIScrollView) {
        parent.reportScroll(
            offset: scrollView.contentOffset.x,
            visibleWidth: scrollView.bounds.width,
            contentWidth: scrollView.contentSize.width,
            to: self
        )
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        let source = textView.text as NSString

        if text == "\t" {
            textView.insertText(String(repeating: " ", count: CodeIndent.width))
            return false
        }

        if text == "\n", parent.editing.autoIndent {
            // Nothing to add, so let UIKit insert it and don't recurse.
            guard let insertion = CodeIndent.newline(in: source, at: range.location) else {
                return true
            }
            textView.insertText(insertion.text)
            textView.selectedRange = NSRange(
                location: range.location + insertion.caret,
                length: 0
            )
            return false
        }

        // A backspace arrives as the preceding character replaced by nothing.
        if text.isEmpty, range.length == 1,
           let target = backspaceRange(at: NSMaxRange(range), in: source),
           let start = textView.position(from: textView.beginningOfDocument, offset: target.location),
           let end = textView.position(from: start, offset: target.length),
           let textRange = textView.textRange(from: start, to: end) {
            textView.replace(textRange, withText: "")
            return false
        }

        if parent.editing.autoPairs, range.length == 0,
           let edit = CodePairs.edit(typing: text, in: source, at: range.location) {
            switch edit {
            case .close(let closer):
                // The pair goes in as one string, which the guard above then
                // lets through untouched.
                textView.insertText(text + closer)
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            case .skip:
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            }
            return false
        }

        return true
    }
}
#endif

// MARK: - macOS

#if os(macOS)
extension CodeTextView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let textView = CodeNSTextView(usingTextLayoutManager: true)
        assert(textView.textLayoutManager != nil, "fell back to TextKit 1")

        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.font = Self.font
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.textContainer?.lineFragmentPadding = 0
        // Resizing itself to the layout is what gives the scroll view its
        // horizontal extent; an autoresizing width would pin it to the clip.
        textView.minSize = .zero
        textView.maxSize = Self.unboundedSize
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = []
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineBreakMode = .byClipping
        textView.textContainer?.size = Self.unboundedSize

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        let scrollView = CodeScrollView()
        scrollView.onScroll = { [coordinator = context.coordinator] clipView in
            coordinator.parent.reportScroll(
                offset: clipView.bounds.origin.x,
                visibleWidth: clipView.bounds.width,
                contentWidth: coordinator.codeWidth,
                to: coordinator
            )
        }
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        // No scrollers: the code scrolls with the trackpad, and an overlay
        // scroller would sit over the last line.
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.verticalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeNSTextView else { return }

        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.isApplyingUpdate = true
        defer { coordinator.isApplyingUpdate = false }

        textView.isEditable = isEditable
        textView.showsIndentGuides = editing.indentGuides
        if textView.font != Self.font {
            textView.font = Self.font
        }
        // A view inset rather than the container's line padding, which TextKit 2
        // only applies to the fragments it lays out after the change. AppKit
        // insets both edges; the trailing one is invisible as the code scrolls.
        let insets = NSSize(width: leadingInset, height: Self.verticalInset)
        if textView.textContainerInset != insets {
            textView.textContainerInset = insets
            textView.needsDisplay = true
        }

        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
        if let storage = textView.textLayoutManager?.codeTextStorage {
            applyHighlight(to: storage)
        }
        textView.typingAttributes = Self.textAttributes

        if textView.selectedRange() != selection,
           selection.upperBound <= (textView.string as NSString).length {
            textView.setSelectedRange(selection)
        }

        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)

        if let metrics = textView.textLayoutManager?.contentMetrics() {
            reportLineHeight(metrics.lineHeight, to: coordinator)

            // Not the document view's width: it pads its trailing edge by the
            // same inset as the leading one, and that space holds no code.
            coordinator.codeWidth = metrics.width + leadingInset + Self.characterAdvance
            let clip = scrollView.contentView.bounds
            reportScroll(
                offset: clip.origin.x,
                visibleWidth: clip.width,
                contentWidth: coordinator.codeWidth,
                to: coordinator
            )
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? NSTextView,
              let layoutManager = textView.textLayoutManager
        else { return nil }
        let metrics = layoutManager.contentMetrics()

        return CGSize(
            width: Self.width(proposal, contentWidth: metrics.width + leadingInset),
            height: Self.height(metrics.height + Self.verticalInset * 2, proposal: proposal)
        )
    }
}

extension CodeTextView.Coordinator: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard !isApplyingUpdate,
              let textView = notification.object as? NSTextView
        else { return }
        // Typing leaves the view already holding the text, so the update pass
        // sees nothing to write and never invalidates the guides.
        textView.needsDisplay = true
        parent.onTextChange(textView.string)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isApplyingUpdate,
              let textView = notification.object as? NSTextView
        else { return }
        parent.selection = textView.selectedRange()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let selection = textView.selectedRange()

        switch commandSelector {
        case #selector(NSResponder.insertTab(_:)):
            textView.insertText(
                String(repeating: " ", count: CodeIndent.width),
                replacementRange: selection
            )
            return true

        case #selector(NSResponder.insertNewline(_:)):
            // Nothing to add, so let AppKit insert it with its own handling.
            guard parent.editing.autoIndent,
                  let insertion = CodeIndent.newline(
                      in: textView.string as NSString,
                      at: selection.location
                  )
            else { return false }
            textView.insertText(insertion.text, replacementRange: selection)
            textView.setSelectedRange(
                NSRange(location: selection.location + insertion.caret, length: 0)
            )
            return true

        case #selector(NSResponder.deleteBackward(_:)):
            guard selection.length == 0,
                  let target = backspaceRange(at: selection.location, in: textView.string as NSString),
                  textView.shouldChangeText(in: target, replacementString: "")
            else { return false }
            textView.textStorage?.replaceCharacters(in: target, with: "")
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: target.location, length: 0))
            return true

        default:
            return false
        }
    }

    /// More than the one character behind the caret: an empty pair, or a
    /// whole indentation level.
    fileprivate func backspaceRange(at location: Int, in source: NSString) -> NSRange? {
        if parent.editing.autoPairs,
           let pair = CodePairs.emptyPair(in: source, at: location) {
            return pair
        }
        guard parent.editing.autoIndent else { return nil }
        return CodeIndent.outdent(in: source, at: location)
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard parent.editing.autoPairs,
              affectedCharRange.length == 0,
              let typed = replacementString,
              let edit = CodePairs.edit(
                  typing: typed,
                  in: textView.string as NSString,
                  at: affectedCharRange.location
              )
        else { return true }

        switch edit {
        case .close(let closer):
            // The pair goes in as one string, which the guard above then lets
            // through untouched.
            textView.insertText(typed + closer, replacementRange: affectedCharRange)
            textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
        case .skip:
            textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
        }
        return false
    }
}

/// Draws the indent guides over the leading whitespace, which holds no glyph,
/// and refuses the insertion-point reveal AppKit fires while resizing, which
/// would drag the first column in under the gutter.
final class CodeNSTextView: NSTextView {
    var showsIndentGuides = true {
        didSet { if showsIndentGuides != oldValue { needsDisplay = true } }
    }

    private var isResizing = false

    override func setFrameSize(_ newSize: NSSize) {
        isResizing = true
        defer { isResizing = false }
        super.setFrameSize(newSize)
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard !isResizing else { return }
        super.scrollRangeToVisible(range)
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)
        guard showsIndentGuides, let layoutManager = textLayoutManager else { return }
        drawIndentGuides(
            text: string,
            layoutManager: layoutManager,
            inset: CGSize(width: textContainerInset.width, height: textContainerInset.height),
            color: .separatorColor,
            in: rect
        )
    }
}

/// Reports the horizontal scroll, which AppKit offers no callback for. It also
/// fires when the document is resized, so a longer line is noticed too.
private final class CodeScrollView: NSScrollView {
    var onScroll: (@MainActor (NSClipView) -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let origin = contentView.bounds.origin
        super.setFrameSize(newSize)

        // Clamped rather than restored blindly: growing the view can leave the
        // old offset past the end of the code.
        let furthest = max(0, (documentView?.frame.width ?? 0) - contentView.bounds.width)
        let x = min(max(0, origin.x), furthest)
        guard abs(x - contentView.bounds.origin.x) > 0.5 else { return }
        contentView.scroll(to: NSPoint(x: x, y: origin.y))
        reflectScrolledClipView(contentView)
    }

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        onScroll?(clipView)
    }
}
#endif
