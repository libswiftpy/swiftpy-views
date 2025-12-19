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
        Self.setContent(arguments)
    }
    
    struct Content: RepresentationContent {
        @State var model: ScrollView
        
        var body: some View {
            SwiftUI.ScrollView {
                model.contentView
            }
        }
    }
}
