//
//  VStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI

/// A view that arranges its views in a vertical line.
@Scriptable(base: .View)
@Observable
@MainActor
final class VStack {
    /// The views, which can be changed after it's made.
    let content: Group
    /// How the views line up: "leading", "center" or "trailing".
    var alignment: String
    /// The distance between the views; None picks one that suits them.
    var spacing: Double?

    /// Creates a vertical stack.
    ///
    /// content: Views, or strings to show as text.
    /// alignment: How the views line up: "leading", "center" or "trailing". Defaults to "center".
    /// spacing: The distance between the views. Defaults to None, which picks one that suits them.
    init(content: Unpack, alignment: String = "center", spacing: Double? = nil) {
        self.content = Group(objects: content.values)
        self.alignment = alignment
        self.spacing = spacing
    }

    func body() -> AnyView {
        AnyView(VStackContent(model: self))
    }
}

private struct VStackContent: View {
    let model: VStack

    var body: some View {
        SwiftUI.VStack(
            alignment: Alignment.horizontal(model.alignment) ?? .center,
            spacing: model.spacing.map { CGFloat($0) }
        ) {
            model.content.body()
        }
    }
}
