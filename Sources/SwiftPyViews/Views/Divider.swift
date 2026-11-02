//
//  Divider.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A line between views: across a vertical stack, down a horizontal one.
@Scriptable(base: .View)
@MainActor
final class Divider {
    init() {}

    func body() -> AnyView {
        AnyView(SwiftUI.Divider())
    }
}
