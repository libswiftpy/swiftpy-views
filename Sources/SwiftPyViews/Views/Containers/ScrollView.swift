//
//  ScrollView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-02.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
@MainActor
final class ScrollView {
    var views: Views
    
    init(views: Unpack) throws {
        self.views = Views(objects: views.values)
    }

    func body() -> AnyView {
        AnyView(ScrollViewContent(model: self))
    }
}

private struct ScrollViewContent: View {
    @State var model: ScrollView

    var body: some View {
        SwiftUI.ScrollView {
            model.views.body()
        }
    }
}
