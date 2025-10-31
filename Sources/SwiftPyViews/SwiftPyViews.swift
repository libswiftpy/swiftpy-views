// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy

public struct PythonWindows: Scene {
    public init() {
        Interpreter.bindModule("views", [
            Window.self,
            VStack.self,
            Text.self,
        ])
    }
    
    public var body: some Scene {
        WindowGroup(for: Window.ID.self) { $key in
            if let key,
               let window = Window.windows[key] {
                window.content?.view?.view.onDisappear {
                    Window.presentedWindows.remove(key)
                }
            }
        }
    }
}
