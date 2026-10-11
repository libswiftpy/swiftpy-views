//
//  HStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-19.
//

import SwiftPy
import SwiftUI

/// A view that arranges its views in a horizontal line.
@Scriptable(base: .View)
@Observable
@MainActor
final class HStack {
    /// The views, which can be changed after it's made.
    let content: Group
    /// How the views line up: "top", "center" or "bottom".
    var alignment: String
    /// The distance between the views; None picks one that suits them.
    var spacing: Double?

    /// Creates a horizontal stack.
    ///
    /// content: Views, or strings to show as text.
    /// alignment: How the views line up: "top", "center" or "bottom". Defaults to "center".
    /// spacing: The distance between the views. Defaults to None, which picks one that suits them.
    init(content: Unpack, alignment: String = "center", spacing: Double? = nil) {
        self.content = Group(objects: content.values)
        self.alignment = alignment
        self.spacing = spacing
    }

    func body() -> AnyView {
        AnyView(HStackContent(model: self))
    }
}

private struct HStackContent: View {
    let model: HStack

    var body: some View {
        SwiftUI.HStack(
            alignment: Alignment.vertical(model.alignment) ?? .center,
            spacing: model.spacing.map { CGFloat($0) }
        ) {
            model.content.body()
        }
    }
}
