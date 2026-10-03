//
//  SignatureHelpView.swift
//  swiftpy-views
//

import SwiftUI
import SyntaxHighlight

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct CodeSignature: Sendable, Equatable {
    public let label: String
    /// UTF-16 range within the signature label.
    public let activeParameter: NSRange?
    public let parameterDocumentation: String?

    public init(label: String, activeParameter: NSRange? = nil, parameterDocumentation: String? = nil) {
        self.label = label
        let documentation = parameterDocumentation?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.parameterDocumentation = documentation.flatMap { $0.isEmpty ? nil : $0 }
        if let activeParameter, activeParameter.location >= 0,
           activeParameter.length > 0, activeParameter.location <= label.utf16.count,
           activeParameter.length <= label.utf16.count - activeParameter.location,
           let range = Range(activeParameter, in: label),
           label.indices.contains(range.lowerBound),
           range.upperBound == label.endIndex || label.indices.contains(range.upperBound) {
            self.activeParameter = activeParameter
        } else {
            self.activeParameter = nil
        }
    }

    internal func formatted(tokens: [CodeToken], colorScheme: ColorScheme, font: Font = .system(.body, design: .monospaced)) -> AttributedString {
        var result = AttributedString(label)
        for token in tokens {
            guard let stringRange = Range(token.range, in: label),
                  let range = Range(stringRange, in: result) else { continue }
            result[range].foregroundColor = Color(CodePalette.xcode.color(for: token.scope, in: colorScheme))
        }
        if let activeParameter, let stringRange = Range(activeParameter, in: label),
           let range = Range(stringRange, in: result) {
            result[range].font = font.bold()
            result[range].underlineStyle = .single
        }
        return result
    }
}

internal struct SignatureLine: Equatable, Identifiable {
    let range: NSRange
    let height: CGFloat
    let width: CGFloat
    var id: Int { range.location }

    @MainActor
    static func wrap(_ signature: CodeSignature, width: CGFloat, fontSize: CGFloat) -> [SignatureLine] {
        guard width > 0, !signature.label.isEmpty else { return [] }
        #if os(macOS)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let bold = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        #else
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let bold = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        #endif
        let storage = NSTextStorage(string: signature.label, attributes: [.font: font])
        if let active = signature.activeParameter {
            storage.addAttribute(.font, value: bold, range: active)
        }
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        var lines: [SignatureLine] = []
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { rect, usedRect, _, glyphs, _ in
            lines.append(SignatureLine(
                range: manager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil),
                height: ceil(rect.height),
                width: ceil(usedRect.width)
            ))
        }
        return lines
    }
}

internal struct SignatureHelpView: View {
    let signature: CodeSignature

    @Environment(\.colorScheme) private var colorScheme
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 13
    #else
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    #endif
    @State private var width: CGFloat = 0
    @State private var highlightedLabel = ""
    @State private var tokens: [CodeToken] = []

    private var activeText: String? {
        guard let range = signature.activeParameter.flatMap({ Range($0, in: signature.label) }) else { return nil }
        return String(signature.label[range])
    }

    var body: some View {
        let lines = SignatureLine.wrap(signature, width: max(1, width - 24), fontSize: fontSize)
        let formatted = signature.formatted(
            tokens: highlightedLabel == signature.label ? tokens : [],
            colorScheme: colorScheme,
            font: .system(size: fontSize, design: .monospaced)
        )
        let activeLine = lines.first {
            guard let active = signature.activeParameter else { return false }
            return NSLocationInRange(active.location, $0.range)
        }?.id ?? lines.first?.id
        SwiftUI.VStack(alignment: .leading, spacing: 4) {
            ScrollViewReader { proxy in
                SwiftUI.ScrollView(.vertical) {
                    SwiftUI.VStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            if let stringRange = Range(line.range, in: signature.label),
                               let range = Range(stringRange, in: formatted) {
                                SwiftUI.Text(AttributedString(formatted[range]))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: line.height)
                                    .id(line.id)
                            }
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: lines.prefix(3).reduce(0) { $0 + $1.height })
                .onChange(of: activeLine, initial: true) {
                    if let activeLine { proxy.scrollTo(activeLine, anchor: .top) }
                }
                .onChange(of: lines) {
                    if let activeLine { proxy.scrollTo(activeLine, anchor: .top) }
                }
            }
            if let documentation = signature.parameterDocumentation {
                SwiftUI.Text(documentation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: lines.count == 1 ? min(width, (lines.first?.width ?? 0) + 24) : width)
        .glassBackground(in: .rect(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .font(.system(size: fontSize, design: .monospaced))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SwiftUI.Text(verbatim: signature.label))
        .accessibilityValue(activeText.map {
            SwiftUI.Text("Current parameter: \($0)", bundle: .module, comment: "VoiceOver value; the variable is the active Python parameter.")
        } ?? SwiftUI.Text(""))
        .accessibilityHint(SwiftUI.Text(signature.parameterDocumentation ?? ""))
        .accessibilityIdentifier("SignatureHelp")
        .task(id: signature.label) {
            let label = signature.label
            let result = await CodeHighlighter.shared.tokens(for: label, language: "python")
            guard !Task.isCancelled else { return }
            tokens = result
            highlightedLabel = label
        }
    }
}

#Preview("Signature Help") {
    let label = "(name: str, count: int = 1, separator: str = ', ', flush: bool = False) -> str"
    SwiftUI.VStack(spacing: 24) {
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            SignatureHelpView(signature: CodeSignature(
                label: label, activeParameter: (label as NSString).range(of: "count: int = 1"),
                parameterDocumentation: "How many times to repeat the greeting."
            ))
            CompletionsView(completions: ["count", "counter"]) { _ in }
        }
        .environment(\.colorScheme, .light)
        .background(Color(CodePalette.xcode.background(in: .light)))
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            SignatureHelpView(signature: CodeSignature(
                label: label, activeParameter: (label as NSString).range(of: "flush: bool = False")
            ))
            CompletionsView(completions: ["False", "True"]) { _ in }
        }
        .environment(\.colorScheme, .dark)
        .background(Color(CodePalette.xcode.background(in: .dark)))
    }
    .frame(width: 340)
    .padding()
}
