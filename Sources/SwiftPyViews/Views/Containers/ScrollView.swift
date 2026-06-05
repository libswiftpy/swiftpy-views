//
//  ScrollView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-02.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
final class ScrollView: ViewRepresentable {
    var views: Views
    
    init(views: Unpack) throws {
        self.views = Views(objects: views.values)
    }
    
    struct Content: RepresentationContent {
        @State var model: ScrollView
        
        var body: some View {
            SwiftUI.ScrollView {
                model.views.view
            }
        }
    }
}
