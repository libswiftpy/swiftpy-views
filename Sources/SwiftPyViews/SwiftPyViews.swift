// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import pocketpy
import HighlightSwift

public struct PythonWindows: Scene {
    public init() {
        Interpreter.bindModule("views", [
            PythonView.self,
            Button.self,
            CodeView.self,
            ScrollView.self,
            Text.self,
            Thumbnail.self,
            Image.self,
            VStack.self,
            Model3D.self,
            
            Window.self,
        ]) { module in
            let view = module?["View"]

            view?.bind("padding(self) -> View") { _, argv in
                PyAPI.return(PaddingModifier().apply(argv))
            }
        }

        Interpreter.bindModule("audio", [
            AudioPlayer.self,
        ])
        
        Interpreter.bindModule("music", [
            MusicPlayer.self,
            Song.self,
        ])
        
        Interpreter.main.bind("help(module: object) -> None") {
            argc,
            argv in
            PyAPI.returnOrThrow {
                var module = argv
                if let moduleName = String(argv) {
                    module = Interpreter.module(moduleName)
                    guard module != nil else {
                        throw PythonError.ImportError("No module named \(moduleName)")
                    }
                }
                
                let name = try String.cast(module?["__name__"])
                let doc = try String.cast(module?["__doc__"])
                
                let window = Window(id: "help[\(name)]")
                window.view = ViewRepresentation {
                    GeometryReader { geo in
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
                    
                }
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
        window.view?.view
    }
}
