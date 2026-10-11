//
//  ProgressView.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// How far along something is, or a spinner while that isn't known.
@Scriptable(base: .View)
@MainActor
@Observable
final class ProgressView {
    /// How much is done, out of `total`; None shows a spinner.
    var value: Double?
    /// What `value` counts up to.
    var total: Double
    /// Shown with the progress.
    var label: String?

    /// Creates a progress view.
    ///
    /// value: How much is done, out of total. Defaults to None, which shows a spinner.
    /// total: What value counts up to. Defaults to 1.
    /// label: Shown with the progress. Defaults to None.
    init(value: Double? = nil, total: Double = 1, label: String? = nil) {
        self.value = value
        self.total = total
        self.label = label
    }

    func body() -> AnyView {
        AnyView(ProgressViewContent(model: self))
    }
}

private struct ProgressViewContent: View {
    let model: ProgressView

    var body: some View {
        if let value = model.value {
            SwiftUI.ProgressView(value: min(max(value, 0), model.total), total: model.total) {
                if let label = model.label { SwiftUI.Text(label) }
            }
        } else {
            SwiftUI.ProgressView {
                if let label = model.label { SwiftUI.Text(label) }
            }
        }
    }
}
