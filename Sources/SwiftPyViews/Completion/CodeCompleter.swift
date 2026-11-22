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
    func completions(in editor: CodeEditor, source: String, cursor: String.Index) async -> [CodeSuggestion]
    func signatureHelp(in editor: CodeEditor, source: String, cursor: String.Index) async -> CodeSignatureHelp?
    /// A suggestion of the latest completions' declaration and documentation.
    func details(for suggestion: CodeSuggestion) async -> CodeSuggestionDetails?
}

public extension CompletionProvider {
    func signatureHelp(in editor: CodeEditor, source: String, cursor: String.Index) async -> CodeSignatureHelp? {
        nil
    }

    func details(for suggestion: CodeSuggestion) async -> CodeSuggestionDetails? {
        nil
    }
}

/// The suggestions for whichever editor holds the caret.
///
/// Shared through the environment because the editor being completed and the
/// view showing the suggestions sit in different branches of the tree: a card
/// inlined in a document, and the input field at the bottom of it.
@MainActor
@Observable
public final class CodeCompleter {
    /// Suggestions drop down from the caret in regular width, rather than
    /// sitting in the bar. Set once at launch.
    public static var showsDropdown = false

    public private(set) var completions: [CodeSuggestion] = [] {
        didSet {
            if selectedIndex != 0 { selectedIndex = 0 }
            requestDetails()
        }
    }
    /// The dropdown's row that Return applies.
    public private(set) var selectedIndex = 0
    /// Rows' declarations and documentation as the provider resolves them, by
    /// their text: the selected row's, and the callables' in view.
    public private(set) var detailsByText: [String: CodeSuggestionDetails] = [:]
    @ObservationIgnored private var detailsMissing: Set<String> = []
    @ObservationIgnored private var detailsRequest: Task<Void, Never>?
    /// The name being typed, past any dot.
    public private(set) var typedWord = ""
    /// Where the word being completed starts, in window coordinates, a line high.
    public private(set) var anchor: CGRect?
    /// The open paren of the call the caret is in, where signature help lines up.
    public private(set) var callAnchor: CGRect?
    /// Set by ``completionDropdown()`` while the size class lets it show.
    internal var presentsDropdown = false
    /// Escape hid the dropdown, until the next edit.
    public private(set) var isDropdownDismissed = false
    public private(set) var signature: CodeSignatureHelp?
    @ObservationIgnored private var signatureRequest: Task<Void, Never>?
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
        clearSignature()
        anchor = nil
        callAnchor = nil
        detailsByText = [:]
        detailsMissing = []
        focused = editor
        focusedMarkdown = nil
        isEditingMarkdown = false
        target = editor
        isEditing = true
        completions = []
    }

    internal func focus(_ editor: MarkdownEditor) {
        clearSignature()
        anchor = nil
        callAnchor = nil
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
        clearSignature()
        anchor = nil
        callAnchor = nil
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

        // Only when changed: observers redraw on every assignment.
        if isDropdownDismissed { isDropdownDismissed = false }
        request?.cancel()
        updateSignature(editor, source: source, cursor: cursor)

        guard let cursor else {
            completions = []
            return
        }

        let query = CodeCompletion.query(in: source, at: cursor)
        let word = String(query.split(separator: ".", omittingEmptySubsequences: false).last ?? "")
        if typedWord != word { typedWord = word }
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

    // MARK: Dropdown

    /// What the dropdown lists: calls first, as they come, each text once.
    public var dropdownSuggestions: [CodeSuggestion] {
        guard !isEditingMarkdown else { return [] }
        var seen = Set<String>()
        return completions.filter { seen.insert($0.text).inserted }
    }

    /// The dropdown is up, so Return, Tab and the arrows are its own.
    public var isShowingDropdown: Bool {
        canShowDropdown && !dropdownSuggestions.isEmpty
    }

    /// The dropdown shows a call's signature help, under its suggestions or alone.
    public var isShowingSignature: Bool {
        canShowDropdown && signature != nil
    }

    private var canShowDropdown: Bool {
        Self.showsDropdown && presentsDropdown && isEditing && !isDropdownDismissed && anchor != nil
    }

    public var selectedSuggestion: CodeSuggestion? {
        let suggestions = dropdownSuggestions
        return suggestions.indices.contains(selectedIndex) ? suggestions[selectedIndex] : nil
    }

    /// The selected row's declaration and documentation.
    public var details: CodeSuggestionDetails? {
        selectedSuggestion.flatMap { detailsByText[$0.text] }
    }

    public func select(_ index: Int) {
        let count = dropdownSuggestions.count
        guard count > 0 else { return }
        let index = (index % count + count) % count
        guard index != selectedIndex else { return }
        selectedIndex = index
        requestDetails()
    }

    /// Moves the selection by `offset` rows, wrapping around.
    public func moveSelection(by offset: Int) {
        select(selectedIndex + offset)
    }

    public func applySelected() {
        let suggestions = dropdownSuggestions
        guard suggestions.indices.contains(selectedIndex) else { return }
        apply(suggestions[selectedIndex].text)
    }

    public func dismissDropdown() {
        isDropdownDismissed = true
    }

    /// The caret moved on screen, or the word under it did.
    internal func moveAnchor(_ editor: CodeEditor, to new: CompletionAnchor?) {
        guard focused === editor else { return }
        if anchor != new?.word { anchor = new?.word }
        if callAnchor != new?.call { callAnchor = new?.call }
    }

    /// How many rows the dropdown resolves details for: as many as it shows.
    static let detailedRows = 6

    /// The selected row's details first, then the callables' in view, for
    /// their parameters.
    private func requestDetails() {
        detailsRequest?.cancel()
        guard Self.showsDropdown, let provider else { return }
        let suggestions = dropdownSuggestions
        var wanted = selectedSuggestion.map { [$0] } ?? []
        wanted += suggestions.prefix(Self.detailedRows).filter(\.isCallable)
        wanted = wanted.filter { detailsByText[$0.text] == nil && !detailsMissing.contains($0.text) }
        guard !wanted.isEmpty else { return }
        detailsRequest = Task { [weak self] in
            // Arrowing through rows asks only for where it stops.
            try? await Task.sleep(for: .milliseconds(120))
            for suggestion in wanted {
                guard !Task.isCancelled else { return }
                let found = await provider.details(for: suggestion)
                guard !Task.isCancelled, let self else { return }
                if let found {
                    self.detailsByText[suggestion.text] = found
                } else {
                    self.detailsMissing.insert(suggestion.text)
                }
            }
        }
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
        clearSignature()
        request?.cancel()
        events?.cancel()
        events = nil
        pending = nil
        completions = []
    }

    private func clearSignature() {
        signatureRequest?.cancel()
        signatureRequest = nil
        signature = nil
    }

    private func updateSignature(_ editor: CodeEditor, source: String, cursor: String.Index?) {
        signatureRequest?.cancel()
        guard let cursor, let provider else {
            clearSignature()
            return
        }
        signatureRequest = Task { [weak self, weak editor] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let editor else { return }
            let signature = await provider.signatureHelp(in: editor, source: source, cursor: cursor)
            guard !Task.isCancelled, self?.focused === editor,
                  editor.source == source, editor.cursor == cursor else { return }
            self?.signature = signature
        }
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
        completions = suggestions.map { CodeSuggestion(text: $0) }
    }
}
