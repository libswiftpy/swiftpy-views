// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy

@MainActor
public func initialize() {
    PyBind.module("views", docs: "Views to build user interfaces with.") { module in
        module.classes(
            Markdown.self,
            Window.self,
        )
    }
}

public struct PythonWindows: Scene {
    public init() {
        SwiftPyViews.initialize()
    }

    public var body: some Scene {
        WindowGroup(for: Window.ID.self) { $key in
            if let key,
               let window = Window.windows[key] {
                WindowContent(window: window)
            }
        }
    }
}
