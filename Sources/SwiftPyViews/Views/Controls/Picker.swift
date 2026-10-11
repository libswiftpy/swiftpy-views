//
//  Picker.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A choice of one option from several.
@Scriptable(base: .View)
@MainActor
@Observable
final class Picker {
    /// What the picker chooses.
    var label: String
    /// The options: a list of strings, or a dict from each option's value to
    /// the title shown for it.
    var options: PyObject
    /// The chosen option's value, or None.
    var selection: String?
    /// "menu", "segmented" or "inline".
    var style: String
    /// Called with the chosen value when the user picks one. A change from
    /// code doesn't call it.
    var onChange: PyObject?

    /// Creates a picker.
    ///
    /// label: What the picker chooses.
    /// options: A list of strings, or a dict from each option's value to the title shown for it.
    /// selection: The chosen option's value. Defaults to None.
    /// style: "menu", "segmented" or "inline". Defaults to "menu".
    /// on_change: Called with the chosen value when the user picks one.
    init(
        label: String,
        options: PyObject,
        selection: String? = nil,
        style: String = "menu",
        onChange: PyObject? = nil
    ) {
        self.label = label
        self.options = options
        self.selection = selection
        self.style = style
        self.onChange = onChange
    }

    func body() -> AnyView {
        AnyView(PickerContent(model: self))
    }

    /// Each option's value and title, in order.
    internal var choices: [(value: String, title: String)] {
        // Through `list()`: only a list converts, and a dict keeps its order.
        guard let list = try? py.module("builtins")?.throwing.list else { return [] }
        let values: [String] = (try? list(options)) ?? []
        guard options.typeName == "dict",
              let dictValues: PyObject = try? options.throwing.values().object,
              let titles: [String] = try? list(dictValues)
        else {
            return values.map { ($0, $0) }
        }
        return Array(zip(values, titles))
    }

    internal func userChange(to newValue: String?) {
        guard newValue != selection else { return }
        selection = newValue
        if let newValue {
            onChange?.callback(with: newValue)
        }
    }
}

private struct PickerContent: View {
    let model: Picker

    var body: some View {
        let picker = SwiftUI.Picker(
            model.label,
            selection: Binding { model.selection } set: { model.userChange(to: $0) }
        ) {
            ForEach(model.choices, id: \.value) { choice in
                SwiftUI.Text(choice.title).tag(Optional(choice.value))
            }
        }
        switch model.style {
        case "segmented": picker.pickerStyle(.segmented)
        case "inline": picker.pickerStyle(.inline)
        default: picker.pickerStyle(.menu)
        }
    }
}
