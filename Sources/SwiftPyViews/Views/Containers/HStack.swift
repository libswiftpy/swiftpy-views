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
final class HStack: ViewRepresentable, Container {
    init(arguments: PyArguments) {
        Self.setContent(arguments)
    }

    struct Content: RepresentationContent {
        @State var model: HStack
        
        var body: some View {
            SwiftUI.HStack {
                model.contentView
            }
        }
    }
}
