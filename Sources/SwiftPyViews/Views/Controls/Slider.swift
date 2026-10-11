//
//  Slider.swift
//  swiftpy-views
//

import SwiftUI
import SwiftPy

/// A control for picking a value by sliding: between 0 and `steps` in whole
/// steps, marked with ticks, or freely between 0 and 1.
///
/// ```python
/// import views
///
/// views.Slider(value=3, steps=10, on_change=lambda value: print(value))
/// ```
@Scriptable(base: .View)
@MainActor
@Observable
public final class Slider {
    /// The selected value.
    public var value: Double
    /// The highest of the whole values the thumb stops at, from 0; None slides
    /// freely from 0 to 1.
    public var steps: Int?
    /// What the slider sets, read by VoiceOver.
    public var label: String
    /// Called with the new value when the user changes it. A change from code
    /// doesn't call it.
    public var onChange: PyObject?

    /// Past this many stops, ticks would draw a solid bar.
    internal static let tickLimit = 50

    /// Creates a slider.
    ///
    /// value: The selected value. Defaults to 0.
    /// steps: The highest whole value, each marked with a tick. Defaults to None, sliding freely from 0 to 1.
    /// label: What the slider sets, read by VoiceOver.
    /// on_change: Called with the new value when the user changes it.
    public init(
        value: Double = 0,
        steps: Int? = nil,
        label: String = "",
        onChange: PyObject? = nil
    ) {
        self.value = value
        self.steps = steps
        self.label = label
        self.onChange = onChange
    }

    public func body() -> AnyView {
        AnyView(SliderContent(model: self))
    }

    internal var bounds: ClosedRange<Double> {
        0...Double(max(steps ?? 1, 1))
    }

    /// The stops, when there are few enough to mark.
    internal var tickValues: [Double] {
        guard let steps, steps > 0, steps < Self.tickLimit else { return [] }
        return (0...steps).map(Double.init)
    }

    /// What the control's binding does with the user's change.
    internal func userChange(to newValue: Double) {
        value = newValue
        onChange?.callback(with: newValue)
    }
}

private struct SliderContent: View {
    @State var model: Slider

    var body: some View {
        let value = Binding { model.value } set: { model.userChange(to: $0) }
        if let steps = model.steps, steps > 0 {
            SwiftUI.Slider(
                value: value,
                in: model.bounds,
                step: 1,
                label: { SwiftUI.Text(model.label) },
                tick: { model.tickValues.isEmpty ? nil : SliderTick($0) }
            )
        } else {
            SwiftUI.Slider(value: value, in: model.bounds) {
                SwiftUI.Text(model.label)
            }
        }
    }
}

#Preview {
    Slider(value: 3, steps: 10, label: "Level").body()
        .padding()
}
