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
    var title: String?

    /// Creates a section.
    ///
    /// content: Views, or strings to show as text.
    /// title: Shown above the views. Defaults to None.
    init(content: Unpack, title: String? = nil) {
        self.content = Group(objects: content.values)
        self.title = title
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
            if let title = model.title {
                SwiftUI.Text(title)
            }
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

                items = Section("Two", title="Items")
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
