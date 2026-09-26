// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy

@MainActor
public func initialize() {
    // The native module is private, as in the standard library: `views` is a
    // Python file that re-exports the parts that are ready to be used.
    PyBind.module("_views", docs: "Native views.") { module in
        // `WebPageView` is left out while it still crashes: unregistered, it
        // cannot be reached from Python at all.
        module.classes(
            Markdown.self,
            Window.self,
            CodeEditor.self,
        )
    }

    PyBind.module("views", in: .module)
}

@MainActor
public struct PythonWindowNavigator {
    fileprivate let window: Window

    public func push(title: String? = nil, content: AnyView) {
        window.navigate(title: title, to: content)
    }
}

public struct PythonWindows: Scene {
    public init() {
        SwiftPyViews.initialize()
    }

    /// Presents SwiftUI content using the same backing window as Python `Window`.
    @MainActor
    public static func present(
        title: String? = nil,
        sheet: Bool = false,
        content: (PythonWindowNavigator) -> AnyView
    ) {
        let window = Window(title: title, sheet: sheet)
        let navigator = PythonWindowNavigator(window: window)
        window.collect(content(navigator))
        window.show()
    }

    public var body: some Scene {
        #if os(macOS)
        windows
            .restorationBehavior(.disabled)
            .defaultLaunchBehavior(.suppressed)
            .commandsRemoved()
        #else
        windows
        #endif
    }

    private var windows: some Scene {
        WindowGroup(for: Window.ID.self) { $key in
            if let key,
               let window = Window.windows[key] {
                WindowContent(window: window)
            }
        }
    }
}
