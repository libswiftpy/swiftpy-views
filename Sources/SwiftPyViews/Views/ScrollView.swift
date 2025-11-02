//
//  ScrollView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-02.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
final class ScrollView: ViewRepresentable, Container {
    init(arguments: PyArguments) throws {
        // Init with list.
        if arguments.count == 2 {
            arguments[Slot.content] = arguments[1]
        }
    }
    
    struct Content: RepresentationContent {
        @State var model: ScrollView
        
        var body: some View {
            SwiftUI.ScrollView {
                ForEach(model.views.enumerated(), id: \.offset) { _, view in
                    view
                }
            }
        }
    }
}
