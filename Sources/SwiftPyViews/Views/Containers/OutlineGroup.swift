//
//  OutlineGroup.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-11.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
final class OutlineGroup: ViewRepresentable {
    @MainActor
    struct Element: Identifiable {
        let id: String
        let children: [Element]?
        let view: AnyView?
        
        init(node: PyObject) throws {
            view = node.asView
            guard let id: String = node.id else {
                throw PythonError.ValueError("Node.id is missing")
            }
            self.id = id
            children = if let children = node.children {
                try Element.fromList(children)
            } else {
                nil
            }
        }
        
        static func fromList(_ list: PyObject) throws -> [Element]? {
            var elements: [Element] = []
            let iter = try py.retain(py.iter(list.reference))
            
            while let node = try? py.retain(py.next(iter.reference)) {
                try elements.append(Element(node: node))
            }
            if elements.isEmpty {
                return nil
            }
            return elements
        }
    }
    
    internal let elements: [Element]
    var action: PyObject

    init(elements: [PyObject], action: PyObject) throws {
        self.elements = try elements.map(Element.init)
        self.action = action
    }

    struct Content: RepresentationContent {
        @State var model: OutlineGroup
        @State private var selection: OutlineGroup.Element.ID?

        var body: some View {
            List(selection: $selection) {
                SwiftUI.OutlineGroup(
                    model.elements,
                    children: \.children
                ) { element in
                    element.view?.tag(element.id)
                }
            }
            .onChange(of: selection) { _, newValue in
                _ = try? model.action(newValue)
            }
        }
    }
}


private struct PreviewOutlineGroup: View {
    init() {
        _ = SwiftPyViews.PythonWindows()
        
        Interpreter.run("""
        from views import *

        class Node:
            def __init__(self, name: str, children=None):
                self.id = name
                self.children = children or []
                self.__view__ = Text(name).__view__

        def select(id: str):
            print(f"selected {id}")

        tree = Node('root', [
            Node('child1', [Node('child2')]),
            Node('child3')
        ])

        sidebar = OutlineGroup([tree], select)
        """)
    }
    
    var body: some View {
        py.main.sidebar?.asView
    }
}

#Preview {
    PreviewOutlineGroup()
}
