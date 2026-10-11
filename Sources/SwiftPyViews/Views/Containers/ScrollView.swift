//
//  ScrollView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-02.
//

import SwiftPy
import SwiftUI

/// A view that scrolls its views when they don't fit.
@Scriptable(base: .View)
@Observable
@MainActor
final class ScrollView {
    /// The views, which can be changed after it's made.
    let content: Group
    /// The direction it scrolls: "vertical" or "horizontal".
    var axis: String

    /// Creates a scroll view.
    ///
    /// content: Views, or strings to show as text.
    /// axis: The direction it scrolls: "vertical" or "horizontal". Defaults to "vertical".
    init(content: Unpack, axis: String = "vertical") {
        self.content = Group(objects: content.values)
        self.axis = axis
    }

    func body() -> AnyView {
        AnyView(ScrollViewContent(model: self))
    }
}

private struct ScrollViewContent: View {
    let model: ScrollView

    var body: some View {
        if model.axis == "horizontal" {
            SwiftUI.ScrollView(.horizontal) {
                SwiftUI.HStack { model.content.body() }
            }
        } else {
            SwiftUI.ScrollView {
                SwiftUI.VStack { model.content.body() }
            }
            .fitsContentHeight()
        }
    }
}
