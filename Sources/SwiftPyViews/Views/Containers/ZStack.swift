//
//  ZStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

@Observable
@Scriptable(base: .View)
final class ZStack: ViewRepresentable {
    var views: Views
    
    init(views: Unpack) {
        self.views = Views(objects: views.values)
    }

    struct Content: RepresentationContent {
        @State var model: ZStack
        
        var body: some View {
            SwiftUI.ZStack {
                model.views.view
            }
        }
    }
}

