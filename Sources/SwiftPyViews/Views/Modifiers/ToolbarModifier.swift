//
//  ToolbarModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-22.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
final class ToolbarModifier: ViewRepresentable, Container {
    init(arguments: PyArguments) throws {
        try arguments.expectedArgCount(3)
        Self.setContent(arguments)
    }
    
    struct Content: RepresentationContent {
        @State var model: ToolbarModifier
        
        var body: some View {
            let views = model.views
            
            if views.count == 2 {
                views[0].toolbar {
                    views[1]
                }
            }
        }
    }
}

@MainActor
func toolbar(self: PyAPI.Reference, content: PyAPI.Reference) throws -> ToolbarModifier {
    let modifier = PyObject(ToolbarModifier.pyType)
    return try modifier(self, content)
}
