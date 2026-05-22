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
final class Group: ViewRepresentable, Container {
    init(arguments: PyArguments) {
        Self.setContent(arguments)
    }

    struct Content: RepresentationContent {
        @State var model: Group
        
        var body: some View {
            SwiftUI.Group {
                model.contentView
            }
        }
    }
}
