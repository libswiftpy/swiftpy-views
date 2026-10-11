//
//  Stepper.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// Minus and plus buttons that step a whole number.
@Scriptable(base: .View)
@MainActor
@Observable
final class Stepper {
    /// What the stepper sets: a view, or a string to show as text.
    var label: PyObject
    /// The number.
    var value: Int
    /// The lowest it steps down to; None has no limit.
    var minimum: Int?
    /// The highest it steps up to; None has no limit.
    var maximum: Int?
    /// How much a tap changes it.
    var step: Int
    /// Called with the new number when the user steps it. A change from code
    /// doesn't call it.
    var onChange: PyObject?

    /// Creates a stepper.
    ///
    /// label: What the stepper sets: a view, or a string to show as text.
    /// value: The number. Defaults to 0.
    /// minimum: The lowest it steps down to. Defaults to None, no limit.
    /// maximum: The highest it steps up to. Defaults to None, no limit.
    /// step: How much a tap changes it. Defaults to 1.
    /// on_change: Called with the new number when the user steps it.
    init(
        label: PyObject,
        value: Int = 0,
        minimum: Int? = nil,
        maximum: Int? = nil,
        step: Int = 1,
        onChange: PyObject? = nil
    ) {
        self.label = label
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
        self.onChange = onChange
    }

    func body() -> AnyView {
        AnyView(StepperContent(model: self))
    }

    internal var canIncrement: Bool { maximum.map { value < $0 } ?? true }
    internal var canDecrement: Bool { minimum.map { value > $0 } ?? true }

    /// Steps up or down, stopping at the limit.
    internal func userStep(up: Bool) {
        var newValue = value + (up ? step : -step)
        if let maximum { newValue = min(newValue, maximum) }
        if let minimum { newValue = max(newValue, minimum) }
        guard newValue != value else { return }
        value = newValue
        onChange?.callback(with: newValue)
    }
}

private struct StepperContent: View {
    let model: Stepper

    var body: some View {
        SwiftUI.Stepper {
            model.label.asView
        } onIncrement: {
            model.canIncrement ? model.userStep(up: true) : ()
        } onDecrement: {
            model.canDecrement ? model.userStep(up: false) : ()
        }
    }
}
