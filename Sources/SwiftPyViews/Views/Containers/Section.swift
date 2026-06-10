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
    init() {
        _ = SwiftPyViews.PythonWindows()
        
        Interpreter.run("""
        from views import *

        section = Section('test')
        section.content = (
            Text('text')
        )
        
        section2 = Section('Test2')(
            Text('text2')
        )
        """)
    }
    
    var body: some View {
        Form {
            py.main.section?.asView
                //.frame(maxWidth: .infinity)
            
            py.main.section2?.asView
        }
    }
}

#Preview {
    SwiftUI.ScrollView {
        PreviewInspector()
            .formStyle(.grouped)
    }
}
