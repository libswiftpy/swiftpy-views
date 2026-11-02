//
//  MarkdownCodeBlockStyle.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-20.
//

import SwiftUI
import MarkdownView
import SyntaxHighlight

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct SwiftPyCodeBlockStyle: MarkdownCodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        SwiftUI.VStack(alignment: .leading, spacing: 4) {
            if let language = configuration.language, !language.isEmpty {
                SwiftUI.Text(language)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            SwiftUI.ScrollView(.horizontal) {
                HighlightedCode(code: configuration.code, language: configuration.language ?? "")
                    .padding(.horizontal, 8)
            }
            .contentMargins(.trailing, 30, for: .scrollContent)
            .scrollIndicators(.hidden)
            .font(.body.monospaced())
        }
        .padding(.vertical, 8)
        .overlay(alignment: .topTrailing) {
            CopyButton(text: configuration.code)
        }
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(.tertiary, in: .rect(cornerRadius: 16).stroke())
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}

/// Code colored by the bundled highlighter. A missing or unbundled fence
/// language leaves it plain rather than guessing one.
private struct HighlightedCode: View {
    let code: String
    let language: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted = MarkdownEditor.Highlighted()

    var body: some View {
        SwiftUI.Text(attributed)
            .task(id: [code, language]) {
                // highlight.js names, and resolves aliases such as `py`, in lowercase.
                let tokens = await CodeHighlighter.shared.tokens(for: code, language: language.lowercased())
                highlighted = MarkdownEditor.Highlighted(text: code, tokens: tokens)
            }
    }

    private var attributed: AttributedString {
        var text = AttributedString(code)
        // Tokens made from other code would color the wrong ranges.
        if highlighted.text == code {
            MarkdownEditor.color(&text, by: highlighted.tokens, in: colorScheme)
        }
        return text
    }
}

private struct CopyButton: View {
    let text: String

    @State private var copied = false

    var body: some View {
        SwiftUI.Button {
            copy()
        } label: {
            SwiftUI.Image(systemName: copied ? "checkmark" : "square.on.square")
                .contentTransition(.symbolEffect(.replace))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 14)
                .padding(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy")
    }

    private func copy() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif

        Task {
            withAnimation { copied = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }
}
