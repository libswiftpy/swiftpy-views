// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import pocketpy

public struct PythonWindows: Scene {
    public init() {
        Interpreter.bindModule("views", [
            PythonView.self,
            Button.self,
            ScrollView.self,
            Text.self,
            Thumbnail.self,
            Image.self,
            VStack.self,
            
            Window.self,
        ]) { module in
            let view = module?["View"]

            view?.bind("padding(self) -> View") { _, argv in
                PyAPI.return(PaddingModifier().apply(argv))
            }
        }

        Interpreter.bindModule("audio", [
            AudioPlayer.self,
        ]) { module in
            module?.bind("play(path: str) -> None") { _, argv in
                PyAPI.returnOrThrow {
                    let path = try String.cast(argv)
                    try AudioPlayer(path: path).play()
                    return
                }
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
        window.content?.anyView
    }
}
