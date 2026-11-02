//
//  Section.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-20.
//

import SwiftPy
import SwiftUI

/// A titled group of views, set apart in a form.
@Scriptable(base: .View)
@Observable
@MainActor
final class Section {
    /// The views, which can be changed after it's made.
    let content: Group
    /// Shown above the views.
    var header: PyObject?
    /// Shown below the views.
    var footer: PyObject?

    /// Creates a section.
    ///
    /// content: Views, or strings to show as text.
    /// header: Shown above the views: a view, or a string to show as a title. Defaults to None.
    /// footer: Shown below the views: a view, or a string to show as a note. Defaults to None.
    init(content: Unpack, header: PyObject? = nil, footer: PyObject? = nil) {
        self.content = Group(objects: content.values)
        self.header = header
        self.footer = footer
    }

    func body() -> AnyView {
        AnyView(SectionContent(model: self))
    }
}

private struct SectionContent: View {
    let model: Section

    var body: some View {
        SwiftUI.Section {
            model.content.body()
        } header: {
            model.header.map(SectionLabel.init)
        } footer: {
            model.footer.map(SectionLabel.init)
        }
    }
}

private struct SectionLabel: View {
    let object: PyObject

    var body: some View {
        if let text = String(object) {
            SwiftUI.Text(text)
        } else {
            // A view keeps its own text, which a form would capitalize.
            object.asView.textCase(nil)
        }
    }
}

private struct PreviewSections: View {
    @State private var form: PyObject?

    init() {
        _ = SwiftPyViews.PythonWindows()
    }

    var body: some View {
        form?.asView
            .task {
                await Interpreter.run("""
                from views import *

                items = Section("Two", header="Items", footer="A note")
                items.content.insert(0, "One")
                form = Form(Section(Text("Text")), items)
                """)
                form = py.main.form
            }
    }
}

#Preview {
    PreviewSections()
}
