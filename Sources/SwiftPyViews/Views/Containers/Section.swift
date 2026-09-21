//
//  Section.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-20.
//

import SwiftPy
import SwiftUI

/// A container view that you can use to add hierarchy.
@Scriptable(base: .View)
@Observable
@MainActor
final class Section {
    var title: String?

    internal var contentRevision = 0

    var content: Views? {
        didSet { contentRevision += 1 }
    }

    init() {}
    
    init(title: String) {
        self.title = title
    }

    func __call__(content: Unpack) -> Section {
        self.content = Views(objects: content.values)
        return self
    }

    func body() -> AnyView {
        AnyView(SectionContent(model: self))
    }
}

private struct SectionContent: View {
    @State var model: Section

    var body: some View {
        SwiftUI.Section {
            model.content?.body()
                .id(model.contentRevision)
        } header: {
            if let title = model.title {
                SwiftUI.Text(title)
            }
        }
    }
}

private struct PreviewInspector: View {
    @State private var section: PyObject?
    @State private var section2: PyObject?

    init() {
        _ = SwiftPyViews.PythonWindows()
    }

    var body: some View {
        Form {
            section?.asView
            section2?.asView
        }
        .task {
            await Interpreter.run("""
            from views import *

            section = Section('test')
            section.content = (
                Text('text')
            )

            section2 = Section('Test2')(
                Text('text2')
            )
            """)
            section = py.main.section
            section2 = py.main.section2
        }
    }
}

#Preview {
    SwiftUI.ScrollView {
        PreviewInspector()
            .formStyle(.grouped)
    }
}
