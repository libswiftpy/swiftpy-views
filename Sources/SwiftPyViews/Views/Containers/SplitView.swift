//
//  SplitView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-05-08.
//

import SwiftPy
import SwiftUI

/// A View with a sidebar and a content.
@Scriptable(base: .View)
@Observable
@MainActor
final class SplitView {
    internal var contentRevision = 0

    var sidebar: PyObject? {
        didSet { contentRevision += 1 }
    }

    var detail: PyObject? {
        didSet { contentRevision += 1 }
    }

    init(sidebar: PyObject, detail: PyObject) {
        self.sidebar = sidebar
        self.detail = detail
    }

    func body() -> AnyView {
        AnyView(SplitViewContent(model: self))
    }
}

private struct SplitViewContent: View {
    @State var model: SplitView

    var body: some View {
        SwiftUI.NavigationSplitView {
            model.sidebar?.asView
        } detail: {
            model.detail?.asView
        }
    }
}
