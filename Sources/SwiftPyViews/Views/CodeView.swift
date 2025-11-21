//
//  CodeView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-21.
//

import SwiftUI
import SwiftPy
import HighlightSwift

@Observable
@Scriptable(base: .View)
class CodeView: ViewRepresentable {
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    struct Content: RepresentationContent {
        @State var model: CodeView

        var body: some View {
            SwiftUI.ScrollView(.horizontal) {
                CodeText(model.text)
                    .highlightLanguage(.python)
                    .padding(4)
            }
        }
    }
}

#Preview {
    CodeView(text: "print('hello')")
        .view
}
