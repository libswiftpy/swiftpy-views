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

    /// What the button is styled for: a `ButtonRole`, or its name.
    var role: ButtonRoleValue?

    /// Whether the button is held down, for controls that act while held,
    /// such as arrows that move a game's character. Always False in a toolbar.
    var isPressed: Bool { pressed }

    internal var pressed = false

    /// Creates a button that displays a custom label.
    ///
    /// label: A view, or a string to show as text.
    /// action: Called when the button is tapped. A coroutine it returns shows progress until it ends.
    /// role: A `ButtonRole`, such as `ButtonRole.DESTRUCTIVE`, or its name, which the button is styled for. Defaults to None.
    init(label: PyObject, action: PyObject? = nil, role: ButtonRoleValue? = nil) {
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
    @Environment(\.buttonLook) private var look

    var body: some View {
        // The glass style doesn't color a destructive role.
        if role == .destructive {
            styled.tint(.red)
        } else {
            styled
        }
    }

    // Drawn by a style of our own, the only kind told when it's pressed; the
    // toolbar's buttons keep the system's.
    @ViewBuilder private var styled: some View {
        if isInToolbar {
            button
        } else {
            button
                .buttonStyle(PressReportingStyle(model: model, look: look))
                .onDisappear { model.pressed = false }
        }
    }

    private var button: some View {
        SwiftUI.Button(role: role) {
            if let task = model.action?.callback(isUserAction: true) {
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
        switch model.role?.name {
        case "destructive": .destructive
        case "cancel": .cancel
        default: nil
        }
    }
}

/// The glass or plain look, which tells the button while it's held down.
private struct PressReportingStyle: ButtonStyle {
    let model: Button
    let look: ButtonLook
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        styled(configuration)
            .opacity(isEnabled ? 1 : 0.5)
            .onChange(of: configuration.isPressed) { model.pressed = $1 }
    }

    @ViewBuilder
    private func styled(_ configuration: Configuration) -> some View {
        switch look {
        case .plain:
            configuration.label
                .opacity(configuration.isPressed ? 0.5 : 1)
                .contentShape(.rect)
        case .glass:
            let label = configuration.label
                .foregroundStyle(configuration.role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(.capsule)
            #if os(visionOS)
            label
                .background(.thinMaterial, in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .hoverEffect()
            #else
            label
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
            #endif
        }
    }
}

#Preview {    
    Button(py.retain("text"))?.body()
}
