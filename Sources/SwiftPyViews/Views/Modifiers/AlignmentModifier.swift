//
//  AlignmentModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
@MainActor
final class AlignmentModifier {
    var content: AnyView
    
    internal var horizontal: HorizontalAlignment?
    internal var vertical: VerticalAlignment?
    
    init(content: AnyView, alignment: String) {
        self.content = content
        self.horizontal = Alignment.horizontal(alignment)
        self.vertical = Alignment.vertical(alignment)
    }

    func body() -> AnyView {
        AnyView(AlignmentModifierContent(model: self))
    }
}

private struct AlignmentModifierContent: View {
    @State var model: AlignmentModifier

    var body: some View {
        model.content.frame(
            maxWidth: model.horizontal == nil ? nil : .infinity,
            maxHeight: model.vertical == nil ? nil : .infinity,
            alignment: SwiftUI.Alignment(
                horizontal: model.horizontal ?? .center,
                vertical: model.vertical ?? .center
            )
        )
    }
}
