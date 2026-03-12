//
//  ClosableModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-03-12.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
class ClosableModifier: Modifier {
    var view: some View {
        ToolbarCloseModifierView(model: self)
    }
}

struct ToolbarCloseModifierView: View {
    @State var model: ClosableModifier
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        model.contentView.toolbar {
            SwiftUI.Button(role: .close) {
                dismiss()
            }
        }
    }
}
