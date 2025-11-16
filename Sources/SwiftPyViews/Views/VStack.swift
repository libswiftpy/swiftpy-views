//
//  VStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI
import pocketpy

@Observable
@Scriptable(base: .View)
final class VStack: ViewRepresentable, Container {
    init(arguments: PyArguments) throws {
        // Init with list.
        if arguments.count == 2 {
            arguments[Slot.content] = arguments[1]
        }
    }

    struct Content: RepresentationContent {
        @State var model: VStack
        
        var body: some View {
            SwiftUI.VStack {
                model.contentView
            }
        }
    }
}
