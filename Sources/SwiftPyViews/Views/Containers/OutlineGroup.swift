//
//  OutlineGroup.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-11.
//

import SwiftUI
import SwiftPy

@Scriptable(base: .View)
final class OutlineGroup: ViewRepresentable, Container {
    @MainActor
    struct Element: Identifiable {
        let id: String
        let children: [Element]?
        let view: AnyView?
        
        init(node: PyAPI.Reference) throws {
            view = node.anyView
            let tempNode = TempPyObject(node)
            guard let id = String(tempNode?.id?.reference) else {
                throw PythonError.ValueError("Node.id is missing")
            }
            self.id = id
            children = if let children = tempNode?.children?.reference {
                try Element.fromList(children)
            } else {
                nil
            }
        }
        
        static func fromList(_ list: PyAPI.Reference) throws -> [Element]? {
            let temp = list.retained
            var elements: [Element] = []
            try temp.iterate { node in
                if let reference = node.reference {
                    try elements.append(Element(node: reference))
                }
            }
            if elements.isEmpty {
                return nil
            }
            return elements
        }
    }
    
    internal let elements: [Element]

    init(arguments: PyArguments) throws {
        try arguments.expectedArgCount(3)
        let arg1 = try PyAPI.Reference.cast(arguments[1])
        elements = try Element.fromList(arg1) ?? []
        arguments[Slot.action] = arguments[2]
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
                let action = TempPyObject(model[.action])
                try? action?(newValue)
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
        PyModule.main.sidebar?.reference.anyView
    }
}

#Preview {
    PreviewOutlineGroup()
}
