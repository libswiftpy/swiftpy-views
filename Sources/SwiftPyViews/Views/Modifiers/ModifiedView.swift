//
//  ModifiedView.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// What a modifier, such as `padding()`, returns: the view it was called on,
/// changed.
@Scriptable(base: .View)
@MainActor
final class ModifiedView {
    // A PyObject, not its view: a Python view inside keeps re-rendering.
    internal let content: PyObject
    internal let modifier: @MainActor (AnyView) -> AnyView

    internal init(content: PyObject, modifier: @escaping @MainActor (AnyView) -> AnyView) {
        self.content = content
        self.modifier = modifier
    }

    func body() -> AnyView {
        modifier(content.asView ?? AnyView(EmptyView()))
    }
}
