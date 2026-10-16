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
    /// Where the views sit: an `Alignment`, such as `Alignment.TOP_LEADING`, or its name.
    var alignment: AlignmentValue

    /// Creates an overlapping stack.
    ///
    /// content: Views, or strings to show as text.
    /// alignment: Where the views sit: an `Alignment`, such as `Alignment.TOP_LEADING`, or its name. Defaults to center.
    init(content: Unpack, alignment: AlignmentValue = "center") {
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
        SwiftUI.ZStack(alignment: Alignment.both(model.alignment.name)) {
            model.content.body()
        }
    }
}
