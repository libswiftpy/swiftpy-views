//
//  Text.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI

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
    @State var model: Text

    var body: some View {
        SwiftUI.Text(model.text)
    }
}
