//
//  ClosableModifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-03-12.
//

import SwiftPy
import SwiftUI

struct ToolbarCloseModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            SwiftUI.Button(role: .close) {
                dismiss()
            }
        }
    }
}
