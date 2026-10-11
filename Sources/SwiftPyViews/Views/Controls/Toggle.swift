//
//  Toggle.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A switch that turns something on or off.
@Scriptable(base: .View)
@MainActor
@Observable
final class Toggle {
    /// What the toggle turns on: a view, or a string to show as text.
    var label: PyObject
    /// Whether it's on.
    var isOn: Bool
    /// Called with the new state when the user flips it. A change from code
    /// doesn't call it.
    var onChange: PyObject?

    /// Creates a toggle.
    ///
    /// label: What the toggle turns on: a view, or a string to show as text.
    /// is_on: Whether it's on. Defaults to False.
    /// on_change: Called with the new state when the user flips it.
    init(label: PyObject, isOn: Bool = false, onChange: PyObject? = nil) {
        self.label = label
        self.isOn = isOn
        self.onChange = onChange
    }

    func body() -> AnyView {
        AnyView(ToggleContent(model: self))
    }

    internal func userChange(to newValue: Bool) {
        isOn = newValue
        onChange?.callback(with: newValue)
    }
}

private struct ToggleContent: View {
    let model: Toggle

    var body: some View {
        SwiftUI.Toggle(isOn: Binding { model.isOn } set: { model.userChange(to: $0) }) {
            model.label.asView
        }
    }
}
