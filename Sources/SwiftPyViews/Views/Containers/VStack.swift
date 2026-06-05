//
//  VStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI

/// A view that arranges its subviews in a vertical line.
@Scriptable(base: .View)
@Observable
final class VStack: ViewRepresentable {
    var views: Views
    
    init(views: Unpack) {
        self.views = Views(objects: views.values)
    }

    struct Content: RepresentationContent {
        @State var model: VStack
        
        var body: some View {
            SwiftUI.VStack {
                model.views.view
            }
        }
    }
}
