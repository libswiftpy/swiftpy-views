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

protocol Container: HasSlots, ViewRepresentable where Slot == ContainerSlot {}

extension Container where Self: PythonBindable {
    private var views: [AnyView] {
        var views: [AnyView] = []
        try? self[.content]?.toStack.iterate { obj in
            guard let reference = obj.reference else { return }

            if let view = reference.view?.view {
                views.append(view)
            }
            
            if let text = String(reference) {
                views.append(AnyView(SwiftUI.Text(text)))
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
    
    static func setContent(_ arguments: PyArguments) {
        if arguments.count == 2 {
            arguments[Slot.content] = arguments[1]
        }
        
        var list = [object]()
        for i in 1..<Int(arguments.count) {
            if let argument = arguments[i] {
                list.append(argument)
            }
        }

        let listRetained = list.toStack
        arguments[Slot.content] = listRetained.reference
    }
}
