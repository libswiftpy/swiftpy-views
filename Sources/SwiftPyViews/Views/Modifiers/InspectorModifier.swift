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
            .inspectorOrSheet(isPresented: $model.isPresented) {
                Form {
                    model.inspector.asView
                }
            }
    }
}

private struct PreviewInspector: View {
    @State private var view: PyObject?

    init() {
        _ = SwiftPyViews.PythonWindows()
    }

    var body: some View {
        view?.asView
            .task {
                await Interpreter.run("""
                from views import *

                view = SplitView(
                    'Sidebar',
                    Text('content').inspector(
                        Text('inspector')
                    ),
                )
                """)
                view = py.main.view
            }
    }
}

#Preview {
    PreviewInspector()
}
