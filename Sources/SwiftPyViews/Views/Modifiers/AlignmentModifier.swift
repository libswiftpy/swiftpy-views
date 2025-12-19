//
//  AlignmentModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

@Observable
@Scriptable(base: .View)
class AlignmentModifier: Modifier {
    var content: object? {
        get { self[.content] }
        set { self[.content] = newValue }
    }
    
    internal var horizontal: HorizontalAlignment?
    internal var vertical: VerticalAlignment?
    
    internal init(horizontal: HorizontalAlignment? = nil, vertical: VerticalAlignment? = nil) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
    
    struct Content: RepresentationContent {
        @State var model: AlignmentModifier

        var body: some View {
            model.contentView.frame(
                maxWidth: model.horizontal == nil ? nil : .infinity,
                maxHeight: model.horizontal == nil ? nil : .infinity,
                alignment: SwiftUI.Alignment(
                    horizontal: model.horizontal ?? .center,
                    vertical: model.vertical ?? .center
                )
            )
        }
    }
}
