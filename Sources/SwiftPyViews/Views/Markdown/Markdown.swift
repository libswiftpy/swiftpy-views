//
//  Markdown.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-20.
//

import SwiftUI
import SwiftPy
import MarkdownView

@Scriptable(base: .View)
@MainActor
@Observable
public final class Markdown {
    public var text: String

    public init(text: String) {
        self.text = text
    }

    public func body() -> AnyView {
        AnyView(MarkdownContent(model: self))
    }
}

public extension EnvironmentValues {
    /// Whether markdown opening with a heading sits flush with the top of its
    /// container.
    @Entry var trimsLeadingHeadingPadding: Bool = false
}

public struct MarkdownContent: View {
    private enum HeadingTopPadding {
        static let large: CGFloat = 24
        static let small: CGFloat = 10
    }

    @Environment(\.trimsLeadingHeadingPadding) private var trimsLeadingHeadingPadding

    @State private var model: Markdown

    public init(model: Markdown) {
        self.model = model
    }

    public var body: some View {
        MarkdownView(model.text)
            .padding(.top, HeadingTopPadding.large, for: .h1, .h2, .h3)
            .padding(.top, HeadingTopPadding.small, for: .h4, .h5, .h6)
            .padding(.top, Optional(-trimmedLeadingHeadingPadding))
            .markdownCodeBlockStyle(SwiftPyCodeBlockStyle())
            .markdownElementRenderer(.image(SymbolImageRenderer(), urlScheme: "sf"))
    }

    private var trimmedLeadingHeadingPadding: CGFloat {
        trimsLeadingHeadingPadding ? leadingHeadingTopPadding : 0
    }

    private var leadingHeadingTopPadding: CGFloat {
        let firstLine = model.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix { !$0.isNewline }

        let level = firstLine.prefix { $0 == "#" }.count

        guard (1...6).contains(level),
              firstLine.dropFirst(level).first == " " else {
            return 0
        }

        return level <= 3 ? HeadingTopPadding.large : HeadingTopPadding.small
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
