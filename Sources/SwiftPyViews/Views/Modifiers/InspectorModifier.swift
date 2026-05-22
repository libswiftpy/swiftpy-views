//
//  InspectorModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-18.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
@Observable
final class InspectorModifier: ViewRepresentable, Container {
    var isPresented: Bool = false

    init(arguments: PyArguments) throws {
        try arguments.expectedArgCount(3)
        Self.setContent(arguments)
    }

    struct Content: RepresentationContent {
        @State var model: InspectorModifier
        
        var body: some View {
            let views = model.views

            if views.count == 2 {
                views[0]
                    .toolbar {
                        SwiftUI.Button {
                            model.isPresented.toggle()
                        } label: {
                            SwiftUI.Image(systemName: "sidebar.trailing")
                        }
                    }
                    .inspector(isPresented: $model.isPresented) {
                        Form {
                            views[1]
                        }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled)
                    }
            }
        }
    }
}

@MainActor
func inspector(self: PyAPI.Reference, content: PyAPI.Reference) throws -> InspectorModifier {
    let modifier = PyObject(InspectorModifier.pyType)
    return try modifier(self, content)
}

private struct PreviewInspector: View {
    init() {
        _ = SwiftPyViews.PythonWindows()
        
        Interpreter.run("""
        from views import *

        view = SplitView(
            'Sidebar',
            Text('content').inspector(
                Text('inspector')
            ),
        )
        """)
    }
    
    var body: some View {
        PyModule.main.view?.reference.anyView
    }
}

#Preview {
    PreviewInspector()
}
