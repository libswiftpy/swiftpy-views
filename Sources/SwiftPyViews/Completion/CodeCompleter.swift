//
//  CodeCompleter.swift
//  swiftpy-views
//

import SwiftUI
import SwiftPy

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Completes from an editor's whole source, where the interpreter only sees
/// the fragment before the caret.
@MainActor
public protocol CompletionProvider: AnyObject {
    /// Suggestions for the identifier ending at `cursor`, each replacing it
    /// whole, as ``CodeCompletion/apply(_:to:at:indent:)`` does.
    func completions(in editor: CodeEditor, source: String, cursor: String.Index) async -> [String]
}

/// The suggestions for whichever editor holds the caret.
///
/// Shared through the environment because the editor being completed and the
/// view showing the suggestions sit in different branches of the tree: a card
/// inlined in a document, and the input field at the bottom of it.
@MainActor
@Observable
public final class CodeCompleter {
    public private(set) var completions: [String] = []
    /// An editor holds the caret, which is what puts the input field into its
    /// completing state.
    public private(set) var isEditing = false
    /// The caret is in Markdown, which has nothing to complete.
    public private(set) var isEditingMarkdown = false

    /// The Markdown editor holding the caret.
    public var markdownEditor: MarkdownEditor? {
        // `isEditingMarkdown` first: it is what observation sees change.
        isEditingMarkdown ? focusedMarkdown : nil
    }

    /// The editor holding the caret has nothing but whitespace.
    public var isEditingBlank: Bool {
        guard isEditing else { return false }
        let text = markdownEditor?.text ?? focused?.source
        return text?.allSatisfy(\.isWhitespace) == true
    }

    /// The editor driving the suggestions.
    @ObservationIgnored private weak var focused: CodeEditor?
    @ObservationIgnored private weak var focusedMarkdown: MarkdownEditor?
    /// Where an applied suggestion goes. Kept past ``resign(_:)`` — see there.
    @ObservationIgnored private weak var target: CodeEditor?
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private var pending: UUID?
    @ObservationIgnored private var events: Task<Void, Never>?
    /// Asked instead of the interpreter when set.
    @ObservationIgnored public var provider: (any CompletionProvider)?

    public init() {}

    /// The editor took the caret, so the suggestions are now its own.
    internal func focus(_ editor: CodeEditor) {
        focused = editor
        focusedMarkdown = nil
        isEditingMarkdown = false
        target = editor
        isEditing = true
        completions = []
    }

    internal func focus(_ editor: MarkdownEditor) {
        focused = nil
        // Nothing may be applied to the code editor left behind.
        target = nil
        focusedMarkdown = editor
        isEditingMarkdown = true
        isEditing = true
        completions = []
        request?.cancel()
    }

    internal func resign(_ editor: MarkdownEditor) {
        guard focusedMarkdown === editor else { return }
        focusedMarkdown = nil
        isEditingMarkdown = false
        isEditing = false
    }

    /// The editor gave the caret up. `target` deliberately stays: on macOS,
    /// clicking a suggestion pulls first responder off the text view before the
    /// button's action runs, and dropping it here would apply to nothing.
    internal func resign(_ editor: CodeEditor) {
        guard focused === editor else { return }
        focused = nil
        isEditing = false
        completions = []
        request?.cancel()
    }

    /// New text from `editor`, ignored unless it is the one holding the caret —
    /// otherwise a background editor's observation loop takes the suggestions
    /// over. A nil cursor means there is nothing to complete.
    internal func update(_ editor: CodeEditor, source: String, cursor: String.Index?) {
        guard focused === editor else { return }

        request?.cancel()

        guard let cursor else {
            completions = []
            return
        }

        let query = CodeCompletion.query(in: source, at: cursor)
        request = Task { [weak self, weak editor] in
            // A keystroke is not a question yet. Without this the editor asks
            // once per key, which is a round trip each over a remote host.
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            if let provider = self?.provider, let editor {
                let suggestions = await provider.completions(in: editor, source: source, cursor: cursor)
                guard !Task.isCancelled else { return }
                self?.completions = suggestions
            } else {
                await self?.send(query)
            }
        }
    }

    /// Applies a suggestion to the editor that last held the caret.
    public func apply(_ completion: String) {
        target?.apply(completion)
        completions = []
    }

    /// Takes the caret off whatever is being completed, which drops the
    /// suggestions with it. A responder-chain hammer: the completer knows
    /// *which* editor is focused but not its text view, and reaching that would
    /// mean threading a signal through the representable on both platforms.
    public func endEditing() {
        #if os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #else
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }

    /// The interpreter connection changed; nothing in flight belongs to it.
    public func reset() {
        request?.cancel()
        events?.cancel()
        events = nil
        pending = nil
        completions = []
    }

    private func send(_ query: String) async {
        observeEvents()

        let token = UUID()
        pending = token
        await Interpreter.connection.perform(
            .complete(token: token, lastComponent: query)
        )
    }

    /// One subscription for the object's life. `LocalInterpreterConnection`
    /// registers a continuation per access to `events` and never drops it, so
    /// subscribing per request would grow that array without bound.
    private func observeEvents() {
        guard events == nil else { return }

        events = Task { [weak self] in
            for await event in await Interpreter.connection.events {
                guard case let .completions(suggestions, token) = event.payload
                else { continue }
                self?.receive(suggestions, for: token)
            }
        }
    }

    private func receive(_ suggestions: [String], for token: UUID) {
        guard token == pending else { return }
        completions = suggestions
    }
}
