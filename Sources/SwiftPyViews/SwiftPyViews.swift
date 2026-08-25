// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import HighlightSwift

@MainActor
public func initialize() {
    PyBind.module("views", docs: "Views to build user interfaces with.") { module in
        module.class(Markdown.self)
    }
}

public struct PythonWindows: Scene {
    public init() {
        SwiftPyViews.initialize()

        py.main.def("help(module: object) -> None") {
            argc,
            argv in
            PyAPI.return {
                var module = argv
                if let moduleName = String(argv) {
                    module = py.module(moduleName)?.reference
                    guard module != nil else {
                        throw PythonError.ImportError("No module named \(moduleName)")
                    }
                }
                
                let name = try String.cast(module?["__name__"])
                let doc = try String.cast(module?["__doc__"])
                
                let window = Window(id: "help[\(name)]")
                let content = GeometryReader { geo in
                    SwiftUI.ScrollView([.horizontal, .vertical]) {
                        CodeText(doc).highlightLanguage(.python)
                            .padding(4)
                            .frame(
                                minWidth: geo.size.width,
                                minHeight: geo.size.height,
                                alignment: .topLeading
                            )
                    }
                }
                window.content = AnyView(erasing: content)
                try window.open()
                return
            }
        }
    }
    
    public var body: some Scene {
        WindowGroup(for: Window.ID.self) { $key in
            if let key,
               let window = Window.windows[key] {
                OpenedWindow(window: window)
            }
        }
    }
}

private struct OpenedWindow: View {
    @State var window: Window
    
    var body: some View {
        window.content
    }
}
