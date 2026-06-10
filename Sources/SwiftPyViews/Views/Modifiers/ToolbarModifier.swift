//
//  ToolbarModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-22.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
@Observable
@MainActor
final class ToolbarModifier {
    var content: AnyView
    var toolbar: PyObject
    
    init(content: AnyView, toolbar: PyObject) {
        self.content = content
        self.toolbar = toolbar
    }

    func body() -> AnyView {
        AnyView(ToolbarModifierContent(model: self))
    }
}

private struct ToolbarModifierContent: View {
    @State var model: ToolbarModifier

    var body: some View {
        model.content.toolbar {
            model.toolbar.asView
        }
    }
}
