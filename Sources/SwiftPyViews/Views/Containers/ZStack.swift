//
//  ZStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

/// A view that lays its views over each other, the first at the back.
@Scriptable(base: .View)
@Observable
@MainActor
final class ZStack {
    /// The views, which can be changed after it's made.
    let content: Group
    /// Where the views sit, such as "center" or "top-leading".
    var alignment: String

    /// Creates an overlapping stack.
    ///
    /// content: Views, or strings to show as text.
    /// alignment: Where the views sit, such as "center" or "top-leading". Defaults to "center".
    init(content: Unpack, alignment: String = "center") {
        self.content = Group(objects: content.values)
        self.alignment = alignment
    }

    func body() -> AnyView {
        AnyView(ZStackContent(model: self))
    }
}

private struct ZStackContent: View {
    let model: ZStack

    var body: some View {
        SwiftUI.ZStack(alignment: Alignment.both(model.alignment)) {
            model.content.body()
        }
    }
}
