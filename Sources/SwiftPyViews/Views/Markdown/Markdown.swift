//
//  Markdown.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-20.
//

import SwiftUI
import SwiftPy
import MarkdownView

/// A view that renders markdown.
@Scriptable(base: .View)
@MainActor
@Observable
public final class Markdown {
    /// The markdown source. Assigning re-renders the view.
    public var text: String

    /// Creates a view that renders markdown.
    ///
    /// text: The markdown source.
    ///
    /// Fenced code blocks are syntax highlighted from their language, and tables
    /// are rendered. An image whose URL uses the `sf` scheme draws an SF Symbol
    /// inline, so `![](sf://checkmark.circle)` shows that symbol.
    public init(text: String) {
        self.text = text
    }

    /// The rendered markdown, as the view a host presents.
    public func body() -> AnyView {
        AnyView(MarkdownContent(model: self))
    }
}

// The raw source rather than what renders from it, which `__repr__` shows too.
extension Markdown: @MainActor CustomStringConvertible {
    public var description: String { text }
}

/// Applied to markdown source before it is parsed, for a host that gives some of
/// the syntax a meaning of its own.
public protocol MarkdownSourceFormat: Sendable {
    func format(_ source: String) -> String
}

public extension EnvironmentValues {
    /// Whether markdown opening with a heading sits flush with the top of its
    /// container.
    @Entry var trimsLeadingHeadingPadding: Bool = false

    // A type rather than a closure: SwiftUI can't compare closures, so one here
    // would invalidate every reader on any environment write.
    @Entry var markdownSourceFormat: (any MarkdownSourceFormat)?
}

public struct MarkdownContent: View {
    private enum HeadingTopPadding {
        static let large: CGFloat = 24
        static let small: CGFloat = 10
    }

    @Environment(\.trimsLeadingHeadingPadding) private var trimsLeadingHeadingPadding
    @Environment(\.markdownSourceFormat) private var markdownSourceFormat

    private let model: Markdown

    public init(model: Markdown) {
        self.model = model
    }

    public var body: some View {
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            ForEach(segments) { segment in
                renderedMarkdown(segment.text)
                    .padding(.top, segment.topPadding)
            }
        }
        .markdownCodeBlockStyle(SwiftPyCodeBlockStyle())
        .markdownElementRenderer(.image(SymbolImageRenderer(), urlScheme: "sf"))
    }

    // `MarkdownText` keeps a paragraph as one run of text, so a custom inline
    // element flows with the words around it. `MarkdownView` builds a paragraph
    // out of separate views, which puts every one of them on its own line.
    @ViewBuilder
    private func renderedMarkdown(_ text: String) -> some View {
        let source = markdownSourceFormat?.format(text) ?? text

        #if os(iOS) || os(macOS)
        MarkdownText(source)
        #else
        // Zeroed so both renderers take their heading spacing from `segments`.
        MarkdownView(source)
            .padding(EdgeInsets(), for: .h1, .h2, .h3, .h4, .h5, .h6)
        #endif
    }

    private struct Segment: Identifiable {
        let id: Int
        let text: String
        let topPadding: CGFloat
    }

    /// The markdown cut into a piece per heading, so each heading can be given
    /// the space above it that neither renderer provides. Paragraphs are never
    /// cut, which is what keeps an inline element flowing with its words.
    private var segments: [Segment] {
        var segments = [Segment]()
        var lines = [Substring]()
        var topPadding: CGFloat = 0
        var isInFence = false

        func endSegment() {
            guard !lines.isEmpty else { return }

            segments.append(
                Segment(
                    id: segments.count,
                    text: lines.joined(separator: "\n"),
                    // Nothing sits above the first piece to separate it from.
                    topPadding: segments.isEmpty && trimsLeadingHeadingPadding ? 0 : topPadding
                )
            )
            lines = []
        }

        for line in model.text.split(separator: "\n", omittingEmptySubsequences: false) {
            // A `#` inside a fence is code, not a heading.
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                isInFence.toggle()
            }

            if !isInFence, let level = headingLevel(of: line) {
                endSegment()
                topPadding = level <= 3 ? HeadingTopPadding.large : HeadingTopPadding.small
            }

            lines.append(line)
        }
        endSegment()

        return segments
    }

    /// An indented `#` belongs to whatever contains it, so only a line starting
    /// with one counts.
    private func headingLevel(of line: Substring) -> Int? {
        let level = line.prefix { $0 == "#" }.count

        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }

        return level
    }
}

#Preview {
    SwiftUI.ScrollView {
        MarkdownContent(model: Markdown(text: """
        # Markdown

        Reusable markdown from SwiftPyViews.

        ```python
        print("hello")
        ```
        """))
        .padding(8)
    }
}

#Preview("Heading spacing") {
    let markdown = Markdown(text: """
    # Leading heading

    Prose under the leading heading.

    ## Second heading

    Prose that has a heading above it.

    ```python
    # A comment, not a heading
    print("hello")
    ```

    #### Fourth level

    Closing prose.
    """)

    SwiftUI.ScrollView {
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            MarkdownContent(model: markdown)
                .environment(\.trimsLeadingHeadingPadding, true)

            Divider()

            MarkdownContent(model: markdown)
                .environment(\.trimsLeadingHeadingPadding, false)
        }
        .padding(8)
    }
}
