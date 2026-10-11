////
////  Button.swift
////  swiftpy-views
////
////  Created by Tibor Felföldy on 2025-11-01.
////

import SwiftPy
import SwiftUI

extension PyObject {
    var asView: AnyView? {
        if let str = String(self) {
            return AnyView(erasing: SwiftUI.Text(str))
        }
        return reference.view
    }
}

/// A control that initiates an action.
@Scriptable(base: .View)
@MainActor
@Observable
final class Button {
    internal var contentRevision = 0
    
    /// A view that describes the purpose of the button's action.
    var label: PyObject {
        didSet { contentRevision += 1 }
    }

    /// The action to perform when the user triggers the button.
    var action: PyObject?

    /// "destructive" or "cancel", which the button is styled for.
    var role: String?

    /// Creates a button that displays a custom label.
    ///
    /// label: A view, or a string to show as text.
    /// action: Called when the button is tapped. A coroutine it returns shows progress until it ends.
    /// role: "destructive" or "cancel", which the button is styled for. Defaults to None.
    init(label: PyObject, action: PyObject? = nil, role: String? = nil) {
        self.label = label
        self.action = action
        self.role = role
    }

    func body() -> AnyView {
        AnyView(ButtonContent(model: self))
    }
}

private struct ButtonContent: View {
    let model: Button
    @State private var isProgressing = false
    @Environment(\.isInToolbar) private var isInToolbar

    var body: some View {
        // The glass style doesn't color a destructive role.
        if role == .destructive {
            styled.tint(.red)
        } else {
            styled
        }
    }

    @ViewBuilder private var styled: some View {
        if isInToolbar {
            button
        } else {
            button.glassButtonStyle()
        }
    }

    private var button: some View {
        SwiftUI.Button(role: role) {
            if let task = model.action?.callback() {
                isProgressing = true
                Task {
                    await task.value
                    isProgressing = false
                }
            }
        } label: {
            model.label.asView
                .opacity(isProgressing ? 0 : 1)
                .overlay {
                    if isProgressing {
                        SwiftUI.ProgressView()
                    }
                }
                .id(model.contentRevision)
        }
        .disabled(isProgressing)
    }

    private var role: ButtonRole? {
        switch model.role {
        case "destructive": .destructive
        case "cancel": .cancel
        default: nil
        }
    }
}

#Preview {    
    Button(py.retain("text"))?.body()
}
