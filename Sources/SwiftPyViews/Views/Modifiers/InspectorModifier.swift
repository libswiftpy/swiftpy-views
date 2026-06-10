////
////  InspectorModifier.swift
////  swiftpy-views
////
////  Created by Tibor Felföldy on 2026-05-18.
////

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
@Observable
@MainActor
final class InspectorModifier {
    var isPresented: Bool = false

    var content: AnyView
    var inspector: PyObject
    
    init(content: AnyView, inspector: PyObject) {
        self.content = content
        self.inspector = inspector
    }
    
    func toggle() {
        isPresented.toggle()
    }

    func body() -> AnyView {
        AnyView(InspectorModifierContent(model: self))
    }
}

private struct InspectorModifierContent: View {
    @State var model: InspectorModifier

    var body: some View {
        model.content
            .toolbar {
                SwiftUI.Button {
                    model.isPresented.toggle()
                } label: {
                    SwiftUI.Image(systemName: "sidebar.trailing")
                }
            }
            .inspector(isPresented: $model.isPresented) {
                Form {
                    model.inspector.asView
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
            }
    }
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
        py.main.view?.asView
    }
}

#Preview {
    PreviewInspector()
}
