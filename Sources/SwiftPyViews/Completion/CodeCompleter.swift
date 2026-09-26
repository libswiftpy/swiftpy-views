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

    /// The editor driving the suggestions.
    @ObservationIgnored private weak var focused: CodeEditor?
    /// Where an applied suggestion goes. Kept past ``resign(_:)`` — see there.
    @ObservationIgnored private weak var target: CodeEditor?
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private var pending: UUID?
    @ObservationIgnored private var events: Task<Void, Never>?

    public init() {}

    /// The editor took the caret, so the suggestions are now its own.
    internal func focus(_ editor: CodeEditor) {
        focused = editor
        target = editor
        isEditing = true
        completions = []
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
        request = Task { [weak self] in
            // A keystroke is not a question yet. Without this the editor asks
            // once per key, which is a round trip each over a remote host.
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await self?.send(query)
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
                await self?.receive(suggestions, for: token)
            }
        }
    }

    private func receive(_ suggestions: [String], for token: UUID) {
        guard token == pending else { return }
        completions = suggestions
    }
}
