//
//  SplitView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-08.
//

import SwiftPy
import SwiftUI

///// A View with a sidebar and a content.
//@Scriptable(base: .View)
//final class SplitView: ViewRepresentable, Container {
//
//    init(arguments: PyArguments) throws {
//        try arguments.expectedArgCount(3)
//        Self.setContent(arguments)
//    }
//
//    struct Content: RepresentationContent {
//        @State var model: SplitView
//        
//        var body: some View {
//            let views = model.views
//
//            if views.count == 2 {
//                SwiftUI.NavigationSplitView {
//                    views[0]
//                } detail: {
//                    views[1]
//                }
//            }
//        }
//    }
//}
