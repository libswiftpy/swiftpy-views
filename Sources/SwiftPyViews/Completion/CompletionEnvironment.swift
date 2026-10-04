//
//  CompletionEnvironment.swift
//  swiftpy-views
//

import SwiftUI

public extension EnvironmentValues {
    /// Shared by the editors in a subtree: whichever holds the caret drives it.
    @Entry var codeCompleter: CodeCompleter?
}

public extension View {
    /// Lets the editors in this subtree complete against `completer`, and the
    /// views that show suggestions read them from it.
    func completable(_ completer: CodeCompleter?) -> some View {
        environment(\.codeCompleter, completer)
    }
}

/// The suggestions for whatever holds the caret, wherever they belong on
/// screen. A leaf of its own, so a response repaints the bar rather than the
/// whole field around it.
///
/// A call's signature help takes the full width; `leading` and `trailing` sit
/// beside the suggestions under it.
public struct CompletionBar<Leading: View, Trailing: View>: View {
    /// A tapped call's signature help, shown until pyright's own arrives.
    private struct Expansion: Equatable {
        let id: String
        let signature: CodeSignatureHelp
    }

    @Environment(\.codeCompleter) private var completer
    @State private var expansion: Expansion?
    private let leading: Leading
    private let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        // Not even the tab fallback: Markdown isn't indented by it.
        let completes = completer?.isEditingMarkdown != true
        let completions = completes ? completer?.completions ?? [] : []
        let calls = completions.filter { $0.signature != nil }
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            // The calls of the name at the caret, where their signature help will be.
            if !calls.isEmpty {
                SwiftUI.HStack {
                    ForEach(calls, id: \.text) { call in
                        SuggestionChip(suggestion: call) { apply(call) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .glassChipStyle()
                .buttonBorderShape(.capsule)
                .monospaced()
            } else if completes, let signature = completer?.signature ?? expansion?.signature {
                // Grows from where the chip was. Only drawn scaled: a matched
                // geometry gave it the chip's width to wrap the signature in.
                SignatureHelpView(help: signature)
                    .transition(.scale(scale: 0.4, anchor: .topLeading).combined(with: .opacity))
            }

            SwiftUI.HStack(spacing: 0) {
                leading

                if completes {
                    CompletionsView(completions: completions.filter { $0.signature == nil }) { suggestion in
                        completer?.apply(suggestion.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Keeps `trailing` trailing when there are no suggestions.
                Spacer(minLength: 0)

                trailing
            }
        }
        .onChange(of: completer?.signature) {
            if completer?.signature != nil { expansion = nil }
        }
        .onChange(of: completer?.isEditing) { expansion = nil }
        // In case no signature help comes.
        .task(id: expansion) {
            guard expansion != nil else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { expansion = nil }
        }
    }

    /// `f(` grows into its signature help; `f()` has none to show.
    private func apply(_ call: CodeSuggestion) {
        withAnimation(.snappy) {
            if call.text.hasSuffix("("), let signature = call.signature {
                expansion = Expansion(id: call.text, signature: signature)
            }
            completer?.apply(call.text)
        }
    }
}
