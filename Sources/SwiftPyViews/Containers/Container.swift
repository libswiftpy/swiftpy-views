//
//  Container.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-15.
//

import SwiftPy
import SwiftUI

enum ContainerSlot: Int32, CaseIterable {
    case content
    case action
}

@MainActor
extension PyAPI.Reference {
    var anyView: AnyView? {
        view?.view
    }
}

protocol Container: HasSlots where Slot == ContainerSlot {}

extension Container where Self: PythonBindable {
    private var views: [AnyView] {
        var views: [AnyView] = []
        try? self[.content]?.toStack.iterate { ref in
            if let view = ref.reference?.view?.view {
                views.append(view)
            }
        }
        return views
    }
    
    var contentView: AnyView {
        if let view = self[.content]?.view?.view {
            return view
        }

        return AnyView(
            ForEach(Array(views.enumerated()), id: \.offset) { offset, view in
                view
            }
        )
    }
}
