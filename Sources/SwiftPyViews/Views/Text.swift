//
//  Text.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI

/// A view that shows a line or more of text.
@Scriptable(base: .View)
@MainActor
@Observable
final class Text {
    var text: String

    init(text: String) {
        self.text = text
    }

    func body() -> AnyView {
        AnyView(TextContent(model: self))
    }
}

private struct TextContent: View {
    let model: Text

    var body: some View {
        SwiftUI.Text(model.text)
    }
}
