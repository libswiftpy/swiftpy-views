//
//  SwiftPyDrawing.swift
//  swiftpy-views
//

import SwiftPy

@MainActor
public enum SwiftPyDrawing {
    /// Registers `drawing`; `views` must be registered first.
    public static func initialize() {
        // Native, then re-exported by `drawing` beside what's written in Python.
        PyBind.module("_drawing", docs: "Native drawing.") { module in
            module.classes(Canvas.self, Stroke.self)
        }
        PyBind.module("drawing", in: .module)
    }
}
