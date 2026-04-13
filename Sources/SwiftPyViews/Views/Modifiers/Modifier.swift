//
//  Modifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-15.
//

import SwiftPy
import SwiftUI

protocol Modifier: Container {}

extension Modifier where Self: PythonBindable {
    func apply(_ content: PyAPI.Reference?) -> object? {
        let modifierRetained = retained
        self[.content] = content
        return modifierRetained.reference
    }
}

@Scriptable(base: .View)
class AnyModifier: Modifier {
    let modification: (AnyView) -> AnyView
    
    internal init<Content: View>(
        @ViewBuilder modification: @escaping (AnyView) -> Content
    ) {
        self.modification = { AnyView(modification($0)) }
    }

    var view: some View {
        modification(contentView)
    }
}
