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
@MainActor
final class Group {
    var content: Views

    init(content: Unpack) {
        self.content = Views(objects: content.values)
    }

    func append(item: PyObject) {
        content.append(item)
    }
    
    func body() -> AnyView {
        AnyView(GroupContent(model: self))
    }
}

private struct GroupContent: View {
    @State var model: Group
    
    var body: some View {
        SwiftUI.Group {
            model.content.body()
        }
    }
}
