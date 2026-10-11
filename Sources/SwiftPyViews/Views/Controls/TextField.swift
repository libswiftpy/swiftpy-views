//
//  TextField.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A field to type a line of text in.
@Scriptable(base: .View)
@MainActor
@Observable
final class TextField {
    /// Shown while the field is empty.
    var prompt: String
    /// The text in the field.
    var text: String
    /// Hides what's typed, for a password.
    var secure: Bool
    /// Called with the new text when the user changes it. A change from code
    /// doesn't call it.
    var onChange: PyObject?
    /// Called when the user presses Return.
    var onSubmit: PyObject?

    /// Creates a text field.
    ///
    /// prompt: Shown while the field is empty. Defaults to "".
    /// text: The text in the field. Defaults to "".
    /// secure: Hides what's typed, for a password. Defaults to False.
    /// on_change: Called with the new text when the user changes it.
    /// on_submit: Called when the user presses Return.
    init(
        prompt: String = "",
        text: String = "",
        secure: Bool = false,
        onChange: PyObject? = nil,
        onSubmit: PyObject? = nil
    ) {
        self.prompt = prompt
        self.text = text
        self.secure = secure
        self.onChange = onChange
        self.onSubmit = onSubmit
    }

    func body() -> AnyView {
        AnyView(TextFieldContent(model: self))
    }

    internal func userChange(to newText: String) {
        guard newText != text else { return }
        text = newText
        onChange?.callback(with: newText)
    }

    internal func submit() {
        onSubmit?.callback()
    }
}

private struct TextFieldContent: View {
    let model: TextField

    var body: some View {
        let text = Binding { model.text } set: { model.userChange(to: $0) }
        SwiftUI.Group {
            if model.secure {
                SecureField(model.prompt, text: text)
            } else {
                SwiftUI.TextField(model.prompt, text: text)
            }
        }
        .onSubmit { model.submit() }
    }
}
