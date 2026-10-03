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

public struct CodeSignature: Sendable, Hashable {
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

/// A call's overloads, with the one its arguments match selected.
public struct CodeSignatureHelp: Sendable, Hashable {
    public let signatures: [CodeSignature]
    public let selected: Int

    public var current: CodeSignature { signatures[selected] }

    /// Nil without signatures; an out-of-range `selected` picks the first.
    public init?(signatures: [CodeSignature], selected: Int = 0) {
        guard !signatures.isEmpty else { return nil }
        self.signatures = signatures
        self.selected = signatures.indices.contains(selected) ? selected : 0
    }

    public init(_ signature: CodeSignature) {
        signatures = [signature]
        selected = 0
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
    let help: CodeSignatureHelp

    @Environment(\.colorScheme) private var colorScheme
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 13
    #else
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    #endif
    @State private var width: CGFloat = 0
    @State private var stepperWidth: CGFloat = 0
    @State private var highlightedLabel = ""
    @State private var tokens: [CodeToken] = []
    /// The overload stepped to, kept over pyright's pick until the overloads change.
    @State private var picked: Int?

    private var index: Int {
        picked.flatMap { help.signatures.indices.contains($0) ? $0 : nil } ?? help.selected
    }

    private var signature: CodeSignature { help.signatures[index] }

    private var activeText: String? {
        guard let range = signature.activeParameter.flatMap({ Range($0, in: signature.label) }) else { return nil }
        return String(signature.label[range])
    }

    var body: some View {
        let stepper = help.signatures.count > 1 ? stepperWidth + 8 : 0
        // A floor: wrapping a long signature into a sliver lays out a line per character.
        let lines = SignatureLine.wrap(signature, width: max(120, width - 24 - stepper), fontSize: fontSize)
        SwiftUI.HStack(alignment: .top, spacing: 8) {
            details(lines)
            if help.signatures.count > 1 {
                overloads
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: lines.count == 1 ? min(width, (lines.first?.width ?? 0) + 24 + stepper) : width)
        .glassBackground(in: .rect(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .font(.system(size: fontSize, design: .monospaced))
        .onChange(of: help.signatures) { picked = nil }
        .task(id: signature.label) {
            let label = signature.label
            let result = await CodeHighlighter.shared.tokens(for: label, language: "python")
            guard !Task.isCancelled else { return }
            tokens = result
            highlightedLabel = label
        }
    }

    private func details(_ lines: [SignatureLine]) -> some View {
        let formatted = signature.formatted(
            tokens: highlightedLabel == signature.label ? tokens : [],
            colorScheme: colorScheme,
            font: .system(size: fontSize, design: .monospaced)
        )
        let activeLine = lines.first {
            guard let active = signature.activeParameter else { return false }
            return NSLocationInRange(active.location, $0.range)
        }?.id ?? lines.first?.id
        return SwiftUI.VStack(alignment: .leading, spacing: 4) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SwiftUI.Text(verbatim: signature.label))
        .accessibilityValue(activeText.map {
            SwiftUI.Text("Current parameter: \($0)", bundle: .module, comment: "VoiceOver value; the variable is the active Python parameter.")
        } ?? SwiftUI.Text(""))
        .accessibilityHint(SwiftUI.Text(signature.parameterDocumentation ?? ""))
        .accessibilityIdentifier("SignatureHelp")
    }

    /// Which overload shows, and the stepper that moves through them.
    private var overloads: some View {
        SwiftUI.HStack(spacing: 4) {
            SwiftUI.Text(verbatim: "\(index + 1)/\(help.signatures.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            SwiftUI.Stepper(
                value: Binding { index } set: { picked = $0 },
                in: 0...(help.signatures.count - 1)
            ) {
                SwiftUI.Text("Overload", bundle: .module, comment: "VoiceOver label of the stepper through a function's signatures.")
            }
            .labelsHidden()
            .accessibilityValue(SwiftUI.Text(
                "\(index + 1) of \(help.signatures.count)", bundle: .module,
                comment: "VoiceOver value of the overload stepper: the shown signature, of how many."
            ))
        }
        .controlSize(.small)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stepperWidth = $0 }
    }
}

#Preview("Signature Help") {
    let label = "(name: str, count: int = 1, separator: str = ', ', flush: bool = False) -> str"
    SwiftUI.VStack(spacing: 24) {
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            SignatureHelpView(help: CodeSignatureHelp(signatures: [
                CodeSignature(label: "(name: str) -> str"),
                CodeSignature(
                    label: label, activeParameter: (label as NSString).range(of: "count: int = 1"),
                    parameterDocumentation: "How many times to repeat the greeting."
                ),
            ], selected: 1)!)
            CompletionsView(completions: ["count", "counter"]) { _ in }
        }
        .environment(\.colorScheme, .light)
        .background(Color(CodePalette.xcode.background(in: .light)))
        SwiftUI.VStack(alignment: .leading, spacing: 0) {
            SignatureHelpView(help: CodeSignatureHelp(CodeSignature(
                label: label, activeParameter: (label as NSString).range(of: "flush: bool = False")
            )))
            CompletionsView(completions: ["False", "True"]) { _ in }
        }
        .environment(\.colorScheme, .dark)
        .background(Color(CodePalette.xcode.background(in: .dark)))
    }
    .frame(width: 340)
    .padding()
}
