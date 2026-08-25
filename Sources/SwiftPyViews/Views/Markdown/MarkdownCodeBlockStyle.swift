//
//  MarkdownCodeBlockStyle.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-20.
//

import SwiftUI
import HighlightSwift
import MarkdownView

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
                CodeText(configuration.code)
                    .highlightMode(.languageAlias(alias(for: configuration.language)))
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

    /// Without an explicit language `CodeText` detects one per block, which
    /// colors otherwise identical snippets differently. An unsupported or
    /// missing fence language stays unknown to highlight.js, which leaves the
    /// code plain rather than coloring it as something it is not.
    private func alias(for language: String?) -> String {
        let language = language ?? ""
        return HighlightLanguage.alias(for: language) ?? language
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
