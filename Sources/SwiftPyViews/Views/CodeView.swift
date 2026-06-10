//
//  CodeView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-21.
//

import SwiftUI
import SwiftPy
import HighlightSwift

@Scriptable(base: .View)
@MainActor
@Observable
final class CodeView {
    var text: String

    init(text: String) {
        self.text = text
    }

    func body() -> AnyView {
        AnyView(CodeViewContent(model: self))
    }
}

private struct CodeViewContent: View {
    @State var model: CodeView

    var body: some View {
        SwiftUI.ScrollView(.horizontal) {
            CodeText(model.text)
                .highlightLanguage(.python)
                .padding(4)
        }
    }
}

#Preview {
    CodeView(text: "print('hello')")
        .body()
}
