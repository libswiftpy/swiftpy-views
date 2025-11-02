// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import pocketpy

public struct PythonWindows: Scene {
    public init() {
        Interpreter.bindModule("views", [
            PythonView.self,
            VStack.self,
            Window.self,
            Text.self,
            Button.self,
            Thumbnail.self,
            ScrollView.self,
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
