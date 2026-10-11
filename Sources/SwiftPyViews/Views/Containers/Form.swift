//
//  Form.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// Controls and sections, laid out as a settings screen.
@Scriptable(base: .View)
@Observable
@MainActor
final class Form {
    /// The views, which can be changed after it's made.
    let content: Group
    internal let contentHeight = ContentHeight()

    /// Creates a form.
    ///
    /// content: Sections, views, or strings to show as text.
    init(content: Unpack) {
        self.content = Group(objects: content.values)
    }

    func body() -> AnyView {
        AnyView(FormContent(model: self))
    }
}

private struct FormContent: View {
    let model: Form

    var body: some View {
        SwiftUI.Form {
            model.content.body()
        }
        .formStyle(.grouped)
        .fitsContentHeight(model.contentHeight)
        .fillsAvailableSpace()
    }
}
