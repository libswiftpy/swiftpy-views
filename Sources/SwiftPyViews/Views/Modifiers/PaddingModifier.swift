//
//  PaddingModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-06-10.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
@MainActor
final class PaddingModifier {
    var content: AnyView

    var value: Int?

    init(content: AnyView, value: Int? = nil) {
        self.content = content
        self.value = value
    }

    func body() -> AnyView {
        AnyView(PaddingModifierContent(model: self))
    }
}

private struct PaddingModifierContent: View {
    @State var model: PaddingModifier

    var body: some View {
        if let value = model.value {
            model.content.padding(CGFloat(value))
        } else {
            model.content.padding()
        }
    }
}
