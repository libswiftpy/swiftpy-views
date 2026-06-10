//
//  ZStack.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
@MainActor
final class ZStack {
    var views: Views
    
    init(views: Unpack) {
        self.views = Views(objects: views.values)
    }

    func body() -> AnyView {
        AnyView(ZStackContent(model: self))
    }
}

private struct ZStackContent: View {
    @State var model: ZStack

    var body: some View {
        SwiftUI.ZStack {
            model.views.body()
        }
    }
}
