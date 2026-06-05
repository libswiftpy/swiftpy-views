//
//  HStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-19.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
final class HStack: ViewRepresentable {
    var spacing: Int?
    var content: Views

    init(spacing: Int? = nil) {
        self.spacing = spacing
        self.content = Views(objects: [])
    }

    init(content: Unpack) {
        self.content = Views(objects: content.values)
    }

    func append(item: PyObject) {
        self.content.append(item)
    }
    
    func __call__(views: Unpack) -> HStack {
        content.objects.append(contentsOf: views.values)
        return self
    }

    struct Content: RepresentationContent {
        @State var model: HStack

        var body: some View {
            SwiftUI.HStack(spacing: model.spacing.map(CGFloat.init)) {
                model.content.view
            }
        }
    }
}
