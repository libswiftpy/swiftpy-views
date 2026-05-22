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
final class Section: ViewRepresentable, Container {
    var title: String

    internal var contentRevision = 0

    var content: object? {
        get { self[.content] }
        set {
            self[.content] = newValue
            contentRevision += 1
        }
    }

    init(title: String) {
        self.title = title
    }

    func __call__(content: object?) -> Section {
        let temp = TempPyObject(content)
        self.content = temp?.reference
        return self
    }

    struct Content: RepresentationContent {
        @State var model: Section

        var body: some View {
            SwiftUI.Section(model.title) {
                model.contentView
                    .id(model.contentRevision)
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
            PyModule.main.section?.reference.anyView
                //.frame(maxWidth: .infinity)
            
            PyModule.main.section2?.reference.anyView
        }
    }
}

#Preview {
    SwiftUI.ScrollView {
        PreviewInspector()
            .formStyle(.grouped)
    }
}
