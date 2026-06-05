//
//  Group.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-22.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
final class Group: ViewRepresentable {
    var content: Views

    init(content: Unpack) {
        self.content = Views(objects: content.values)
    }

    func append(item: PyObject) {
        content.append(item)
    }

    struct Content: RepresentationContent {
        @State var model: Group
        
        var body: some View {
            SwiftUI.Group {
                model.content.view
            }
        }
    }
}
