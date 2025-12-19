//
//  PaddingModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-15.
//

import SwiftPy
import SwiftUI

@Observable
@Scriptable(base: .View)
class PaddingModifier: Modifier {
    var content: object? {
        get { self[.content] }
        set { self[.content] = newValue }
    }

    required internal init() {}
    
    struct Content: RepresentationContent {
        @State var model: PaddingModifier

        var body: some View {
            model.contentView.padding()
        }
    }
}
