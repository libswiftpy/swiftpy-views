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
public struct CompletionBar: View {
    @Environment(\.codeCompleter) private var completer

    public init() {}

    public var body: some View {
        CompletionsView(completions: completer?.completions ?? []) { suggestion in
            completer?.apply(suggestion)
        }
    }
}
