//
//  Text.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI

@Observable
@Scriptable
final class Text {
    var text: String

    init(text: String) {
        self.text = text
    }
}

extension Text: ViewRepresentable {
    struct Content: RepresentationContent {
        @State var model: Text

        var body: some View {
            SwiftUI.Text(model.text)
        }
    }
}
