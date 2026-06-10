//
//  Views.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-06-05.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@MainActor
@Observable
final class Views {
    var objects: [PyObject]

    init(objects: [PyObject]) {
        self.objects = objects
    }

    func append(_ item: PyObject) {
        objects.append(item)
    }

    func __getitem__(index: Int) -> PyObject {
        objects[index]
    }
    
    func __setitem__(index: Int, value: PyObject) {
        objects[index] = value
    }

    func __len__() -> Int {
        objects.count
    }
    
    func body() -> AnyView {
        AnyView(ViewsContent(model: self))
    }
}

private struct ViewsContent: View {
    @State var model: Views
    
    var body: some View {
        ForEach(model.objects.enumerated(), id: \.offset) { _, element in
            element.asView
        }
    }
}
