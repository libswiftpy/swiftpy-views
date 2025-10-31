//
//  VStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI
import pocketpy

enum ContainerSlot: Int32, CaseIterable {
    case content
}

protocol Container: HasSlots where Slot == ContainerSlot {}

extension Container where Self: PythonBindable {
    var views: [AnyView] {
        var views: [AnyView] = []
        try? self[.content]?.toStack.iterate { ref in
            if let view = ref.reference?.view?.view {
                views.append(view)
            }
        }
        return views
    }
}

@Observable
@Scriptable
final class VStack: ViewRepresentable, Container {
    init(arguments: PyArguments) throws {
        // Init with list.
        if arguments.count == 2 {
            arguments[Slot.content] = arguments[1]
        }
    }

    struct Content: RepresentationContent {
        @State var model: VStack
        
        var body: some View {
            SwiftUI.VStack {
                ForEach(model.views.enumerated(), id: \.offset) { offset, view in
                    view
                }
            }
        }
    }
}
