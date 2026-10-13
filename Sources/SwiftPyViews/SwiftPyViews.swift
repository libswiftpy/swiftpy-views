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
            MarkdownEditor.self,
            Slider.self,
            ModifiedView.self,
            Text.self,
            Image.self,
            VStack.self,
            HStack.self,
            ZStack.self,
            Group.self,
            ScrollView.self,
            Form.self,
            Section.self,
            Divider.self,
            Rectangle.self,
            Button.self,
            TextField.self,
            Toggle.self,
            Stepper.self,
            Picker.self,
            Progress.self,
        )

        module.def(
            "animate(action: Callable[[], Any]) -> Any",
            docstring: "Calls `action` and animates the changes it makes to views. An `async def` is only called: animate what it changes after an `await` from inside it."
        ) { argc, argv in
            PyBind.function(argc, argv) { (action: PyObject) in
                try withAnimation { try action() }
            }
        }
    }
    ViewModifiers.install()

    PyBind.module("views", in: .module)

    #if DEBUG
    // Only to try out for now; not in release builds.
    PyBind.module("_widgets", docs: "Native widgets.") { module in
        module.classes(Widget.self)
    }
    PyBind.module("widgets", in: .module)
    #endif
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
