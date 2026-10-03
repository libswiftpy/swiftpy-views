//
//  CompletionsView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026. 06. 24..
//

import SwiftUI
import SyntaxHighlight

public struct CompletionsView: View {
    let completions: [CodeSuggestion]
    let completion: (CodeSuggestion) -> Void

    public init(completions: [CodeSuggestion], completion: @escaping (CodeSuggestion) -> Void) {
        var seen = Set<String>()
        self.completions = completions.filter { seen.insert($0.text).inserted }
        self.completion = completion
    }

    public init(completions: [String], completion: @escaping (String) -> Void) {
        self.init(completions: completions.map { CodeSuggestion(text: $0) }) { completion($0.text) }
    }

    // Falls back to a tab suggestion when there are no completions.
    private var suggestions: [CodeSuggestion] {
        completions.isEmpty ? [CodeSuggestion(text: "\t")] : completions
    }

    public var body: some View {
        SwiftUI.ScrollView(.horizontal, showsIndicators: false) {
            SwiftUI.HStack {
                ForEach(suggestions, id: \.text) { suggestion in
                    SuggestionChip(suggestion: suggestion) {
                        completion(suggestion)
                    }
                }
            }
            .padding(8)
            .glassButtonStyle()
            .buttonBorderShape(.capsule)
        }
        .monospaced()
        .mask {
            SwiftUI.HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
        }
    }
}

/// A suggestion's capsule, with its kind's icon; styled by the row it's in.
struct SuggestionChip: View {
    let suggestion: CodeSuggestion
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SwiftUI.Button(action: action) {
            label
        }
    }

    @ViewBuilder
    private var label: some View {
        let text = SwiftUI.Text(suggestion.text, format: .completion)
        if let kind = suggestion.kind {
            SwiftUI.Label {
                text
            } icon: {
                SwiftUI.Image(systemName: kind.symbol)
                    .foregroundStyle(iconStyle(for: kind))
            }
            .labelStyle(.titleAndIcon)
        } else {
            text
        }
    }

    private func iconStyle(for kind: CodeSuggestion.Kind) -> AnyShapeStyle {
        guard let scope = kind.scope else { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(Color(CodePalette.xcode.color(for: scope, in: colorScheme)))
    }
}

#Preview {
    CompletionsView(
        completions: [
            CodeSuggestion(text: "print", kind: .function),
            CodeSuggestion(text: "Agent", kind: .class),
            CodeSuggestion(text: "json", kind: .module),
            CodeSuggestion(text: "import", kind: .keyword),
            CodeSuggestion(text: "None", kind: .constant),
            CodeSuggestion(text: "count", kind: .variable),
            CodeSuggestion(text: "vars()"),
        ]
    ) { _ in }
}
