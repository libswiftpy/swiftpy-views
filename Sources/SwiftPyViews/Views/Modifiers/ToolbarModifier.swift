//
//  ToolbarModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-22.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
final class ToolbarModifier: ViewRepresentable {
    var content: AnyView
    var toolbar: PyObject
    
    init(content: AnyView, toolbar: PyObject) {
        self.content = content
        self.toolbar = toolbar
    }
    
    struct Content: RepresentationContent {
        @State var model: ToolbarModifier
        
        var body: some View {
            model.content.toolbar {
                model.toolbar.asView
            }
        }
    }
}

