//
//  CompletionDropdown.swift
//  swiftpy-views
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SyntaxHighlight

public extension View {
    /// Drops the suggestions down from the caret of an editor in this view,
    /// in regular width; compact width keeps them in the bar. Drawn by the
    /// nearest ``completionDropdownHost()`` above, or here without one.
    func completionDropdown() -> some View {
        modifier(CompletionDropdownModifier())
    }

    /// Draws the dropdowns of the editors in this view over all of it, so
    /// one can reach past a split view column that would clip it.
    func completionDropdownHost() -> some View {
        modifier(CompletionDropdownHostModifier())
    }
}

/// Which completer's dropdown a host draws.
@MainActor
@Observable
final class CompletionDropdownHost {
    var completer: CodeCompleter?
}

extension EnvironmentValues {
    @Entry var completionDropdownHost: CompletionDropdownHost?
}

private struct CompletionDropdownHostModifier: ViewModifier {
    @State private var host = CompletionDropdownHost()

    func body(content: Content) -> some View {
        content
            .environment(\.completionDropdownHost, host)
            .overlay {
                if CodeCompleter.showsDropdown, let completer = host.completer {
                    SwiftUI.GeometryReader { proxy in
                        CompletionDropdownLayer(completer: completer, container: proxy.frame(in: .global))
                    }
                }
            }
    }
}

private struct CompletionDropdownModifier: ViewModifier {
    @Environment(\.codeCompleter) private var completer
    @Environment(\.completionDropdownHost) private var host
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var presents: Bool {
        #if os(macOS)
        CodeCompleter.showsDropdown
        #else
        CodeCompleter.showsDropdown && sizeClass == .regular
        #endif
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if presents, host == nil, let completer {
                    SwiftUI.GeometryReader { proxy in
                        // Its frame is already clear of the keyboard and bars.
                        CompletionDropdownLayer(completer: completer, container: proxy.frame(in: .global))
                    }
                }
            }
            .onChange(of: presents, initial: true) { update() }
            .onDisappear {
                completer?.presentsDropdown = false
                if let host, host.completer === completer { host.completer = nil }
            }
    }

    private func update() {
        completer?.presentsDropdown = presents
        guard let host else { return }
        if presents {
            host.completer = completer
        } else if host.completer === completer {
            host.completer = nil
        }
    }
}

/// Places the panel at the anchor, within the container.
private struct CompletionDropdownLayer: View {
    let completer: CodeCompleter
    let container: CGRect
    @State private var size: CGSize = .zero
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = CompletionDropdownPanel.rowHeight

    /// Unconstrained: all its rows, and room for what's under them.
    private var naturalHeight: CGFloat {
        let rows = completer.isShowingDropdown
            ? min(completer.dropdownSuggestions.count, CompletionDropdownPanel.visibleRows) : 0
        return (rows == 0 ? 0 : CGFloat(rows) * rowHeight + CompletionDropdownPanel.verticalPadding * 2)
            + (completer.isShowingDropdown && completer.details?.documentation != nil ? 56 : 0)
            + (completer.isShowingSignature ? 72 : 0)
    }

    var body: some View {
        // Rows line up with the word; signature help alone, its paren with the call's.
        let rows = completer.isShowingDropdown
        if rows || completer.isShowingSignature,
           let anchor = rows ? completer.anchor : completer.callAnchor ?? completer.anchor,
           let place = CompletionDropdownPlacement.place(
               anchor: anchor, container: container, panel: size, natural: naturalHeight,
               leading: rows ? CompletionDropdownPanel.textInset : CompletionDropdownPanel.detailsInset
           ) {
            CompletionDropdownPanel(completer: completer, maxHeight: place.room, isAbove: place.isAbove)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                // Above the line it hangs from its bottom edge, so a growing
                // panel grows away from the line, without waiting to be measured.
                .alignmentGuide(.top) { place.isAbove ? $0[.bottom] : $0[.top] }
                .offset(x: place.origin.x, y: place.origin.y)
                // Unplaced until measured: its first frame would be at the corner.
                .opacity(size == .zero ? 0 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
        }
    }
}

enum CompletionDropdownPlacement {
    static let gap: CGFloat = 4
    static let margin: CGFloat = 8

    /// The panel's top-leading corner in the container, its text under the
    /// word's start, and the height it may take. Below the line where its
    /// `natural` height fits, else above where that does, else on the side
    /// with more room. Above, `origin.y` is where its bottom edge goes.
    /// Nil while the word is outside the container, scrolled away.
    static func place(anchor: CGRect, container: CGRect, panel: CGSize, natural: CGFloat? = nil, leading: CGFloat)
        -> (origin: CGPoint, room: CGFloat, isAbove: Bool)? {
        let line = anchor.offsetBy(dx: -container.minX, dy: -container.minY)
        guard line.maxY > 0, line.minY < container.height else { return nil }

        // Leftward it may reach the container's edge, over the gutter, so its
        // text still lines up.
        let nearestX: CGFloat = 0
        let furthestX = max(nearestX, container.width - panel.width - margin)
        let x = min(max(nearestX, line.minX - leading), furthestX)

        let natural = natural ?? panel.height
        let below = line.maxY + gap
        let roomBelow = container.height - margin - below
        let roomAbove = line.minY - gap - margin
        if natural <= roomBelow || (natural > roomAbove && roomBelow >= roomAbove) {
            return (CGPoint(x: x, y: below), max(0, roomBelow), false)
        }
        return (CGPoint(x: x, y: line.minY - gap), max(0, roomAbove), true)
    }
}

/// The rows, the selected one tinted, and its documentation.
struct CompletionDropdownPanel: View {
    let completer: CodeCompleter
    /// Where the container is short, the rows scroll and the details truncate.
    var maxHeight: CGFloat = .infinity
    /// Above the line, the documentation goes on top, so the rows stay by it.
    var isAbove = false

    static let padding: CGFloat = 4
    static let verticalPadding: CGFloat = 4
    static let rowPadding: CGFloat = 6
    static let badgeSize: CGFloat = 18
    static let spacing: CGFloat = 6
    /// From the panel's edge to where a row's name starts.
    static let textInset = padding + rowPadding + badgeSize + spacing

    static let rowHeight: CGFloat = 28
    static let visibleRows = 6
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = Self.rowHeight

    /// Where the documentation and signature start, from the panel's edge.
    static let detailsInset: CGFloat = 10

    /// Fits the longest row, between bounds: the rows are monospaced, so it's
    /// known without laying them out, and what's under them wraps to it.
    @MainActor
    static func width(longest: Int) -> CGFloat {
        // Slack for the bold name.
        let trailing: CGFloat = rowPadding + padding + CodeTextView.characterAdvance * 2
        let width = textInset + CGFloat(longest) * CodeTextView.characterAdvance + trailing
        return min(max(width, 280), 480)
    }
    private var visibleRows: Int { Self.visibleRows }

    /// Signature help alone: as wide as its label, up to the rows' widest, where it wraps.
    @MainActor
    static func width(signature label: String) -> CGFloat {
        // In the callout size it's drawn in, smaller than the code's.
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
        #else
        let font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
        #endif
        let advance = NSAttributedString(string: "0", attributes: [.font: font]).size().width
        // A couple of points over, so rounding doesn't wrap the last character.
        let width = CGFloat(label.count) * advance + detailsInset * 2 + 2
        return min(max(width, 120), 480)
    }

    /// A callable's parameters by name: a call's from its signature help,
    /// another's from its resolved declaration.
    private func parameters(_ suggestion: CodeSuggestion) -> String? {
        if let parameters = suggestion.displayParameters { return parameters }
        guard suggestion.isCallable, let signature = completer.detailsByText[suggestion.text]?.signature
        else { return nil }
        return CodeSuggestion.parameterNames(in: signature)
    }

    var body: some View {
        let suggestions = completer.isShowingDropdown ? completer.dropdownSuggestions : []
        let signature = completer.isShowingSignature ? completer.signature : nil
        let rowCount = min(suggestions.count, visibleRows)
        // The rows first, as many as fit; what's under them only in what's left.
        let fullRows = rowCount == 0 ? 0 : CGFloat(rowCount) * rowHeight + Self.verticalPadding * 2
        let rowsHeight = rowCount == 0 ? 0 : min(fullRows, max(rowHeight + Self.verticalPadding * 2, maxHeight))
        let room = maxHeight - rowsHeight
        let documentation = room >= 44 && !suggestions.isEmpty ? completer.details?.documentation : nil
        let showsSignature = signature != nil && (suggestions.isEmpty || room >= 100)
        let width = suggestions.isEmpty
            ? Self.width(signature: signature?.current.label ?? "")
            : Self.width(longest: suggestions.map { $0.displayName.count + (parameters($0)?.count ?? 0) }.max() ?? 0)

        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            // Away from the line: below, under the rows; above, over them.
            if isAbove {
                extras(signature: showsSignature ? signature : nil, documentation: documentation, rowsFollow: !suggestions.isEmpty)
            }
            if !suggestions.isEmpty {
                rows(suggestions, height: rowsHeight)
            }
            if !isAbove {
                extras(signature: showsSignature ? signature : nil, documentation: documentation, rowsFollow: !suggestions.isEmpty)
            }
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .glassBackground(in: .rect(cornerRadius: 16))
        .monospaced()
    }

    /// The selected row's documentation and the call's signature help, each
    /// divided from the rows.
    @ViewBuilder
    private func extras(signature: CodeSignatureHelp?, documentation: String?, rowsFollow: Bool) -> some View {
        let sections = (documentation == nil ? 0 : 1) + (signature == nil ? 0 : 1)
        if sections > 0 {
            if !isAbove, rowsFollow { SwiftUI.Divider() }
            if isAbove, let signature { CompletionSignatureView(help: signature) }
            if let documentation {
                if isAbove, signature != nil { SwiftUI.Divider() }
                CompletionDocumentationView(documentation: documentation)
                if !isAbove, signature != nil { SwiftUI.Divider() }
            }
            if !isAbove, let signature { CompletionSignatureView(help: signature) }
            if isAbove, rowsFollow { SwiftUI.Divider() }
        }
    }

    private func rows(_ suggestions: [CodeSuggestion], height: CGFloat) -> some View {
        SwiftUI.ScrollViewReader { proxy in
            SwiftUI.ScrollView {
                SwiftUI.LazyVStack(alignment: .leading, spacing: 0) {
                    // Identified by text alone: a second identity on the rows
                    // left stale ones drawn, tinted twice.
                    SwiftUI.ForEach(Array(suggestions.enumerated()), id: \.element.text) { index, suggestion in
                        CompletionDropdownRow(
                            suggestion: suggestion,
                            parameters: parameters(suggestion),
                            isNameTyped: suggestion.isCallable && completer.typedWord == suggestion.displayName,
                            isSelected: index == completer.selectedIndex
                        )
                        .frame(height: rowHeight)
                        .contentShape(.rect)
                        .onTapGesture {
                            completer.select(index)
                            completer.applySelected()
                        }
                    }
                }
                .padding(.horizontal, Self.padding)
                .padding(.vertical, Self.verticalPadding)
            }
            .frame(height: height)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: completer.selectedIndex) { _, index in
                if suggestions.indices.contains(index) { proxy.scrollTo(suggestions[index].text) }
            }
        }
    }
}

private struct CompletionDropdownRow: View {
    let suggestion: CodeSuggestion
    let parameters: String?
    /// Its name is typed: what's left to add, its parameters, stands out.
    let isNameTyped: Bool
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SwiftUI.HStack(spacing: CompletionDropdownPanel.spacing) {
            badge
            SwiftUI.HStack(spacing: 0) {
                SwiftUI.Text(suggestion.displayName)
                    .fontWeight(isNameTyped ? .regular : .bold)
                    .foregroundStyle(isNameTyped ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .layoutPriority(1)
                if let parameters {
                    SwiftUI.Text(parameters)
                        .fontWeight(isNameTyped ? .bold : .regular)
                        .foregroundStyle(isNameTyped ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .truncationMode(.tail)
                }
            }
            .lineLimit(1)
            SwiftUI.Spacer(minLength: 0)
        }
        .padding(.horizontal, CompletionDropdownPanel.rowPadding)
        .frame(maxHeight: .infinity)
        .background {
            if isSelected {
                SwiftUI.RoundedRectangle(cornerRadius: 10).fill(.tint.opacity(0.2))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The kind's icon, as the bar's chips show it.
    @ViewBuilder
    private var badge: some View {
        SwiftUI.Group {
            if let kind = suggestion.kind {
                SwiftUI.Image(systemName: kind.symbol)
                    .foregroundStyle(kind.iconStyle(in: colorScheme))
            }
        }
        .font(.subheadline)
        .frame(width: CompletionDropdownPanel.badgeSize)
    }
}

/// The selected suggestion's documentation, its first paragraph.
private struct CompletionDocumentationView: View {
    let documentation: String

    var body: some View {
        SwiftUI.Text(Self.markdown(Self.firstParagraph(of: documentation)))
            .font(.system(.callout, design: .default))
            .monospaced(false)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CompletionDropdownPanel.detailsInset)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Up to the first blank line, on one line.
    static func firstParagraph(of text: String) -> String {
        let paragraph = text.components(separatedBy: "\n\n").first ?? text
        return paragraph.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// Inline Markdown, as docstrings use it; anything else stays as written.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// A call's signature help: the argument at the caret marked, and its description.
private struct CompletionSignatureView: View {
    let help: CodeSignatureHelp

    @Environment(\.colorScheme) private var colorScheme
    /// With the label they were made for: a stale highlight isn't applied.
    @State private var tokens: (label: String, tokens: [CodeToken])?

    var body: some View {
        let signature = help.current
        SwiftUI.VStack(alignment: .leading, spacing: 4) {
            SwiftUI.Text(signature.formatted(
                tokens: tokens?.label == signature.label ? tokens?.tokens ?? [] : [],
                colorScheme: colorScheme,
                font: .system(.callout, design: .monospaced)
            ))
            .font(.system(.callout, design: .monospaced))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            if let documentation = signature.parameterDocumentation {
                SwiftUI.Text(CompletionDocumentationView.markdown(CompletionDocumentationView.firstParagraph(of: documentation)))
                    .font(.system(.callout, design: .default))
                    .monospaced(false)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, CompletionDropdownPanel.detailsInset)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: signature.label) {
            let label = signature.label
            let found = await CodeHighlighter.shared.tokens(for: label, language: "python")
            guard !Task.isCancelled else { return }
            tokens = (label, found)
        }
    }
}
