// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import pocketpy
import HighlightSwift

public struct PythonWindows: Scene {
    public init() {
        PyBind.module("views") { module in
            module.classes(
                Alignment.self,
                
                PythonView.self,
                AnyModifier.self,
                
                Button.self,
                CodeView.self,
                Text.self,
                Thumbnail.self,
                Image.self,
                Model3D.self,
                
                HStack.self,
                ScrollView.self,
                VStack.self,
                ZStack.self,
                SplitView.self,
                OutlineGroup.self,
                InspectorModifier.self,
                
                Window.self,
            )
            
            let view = PyObject(PyType.View).reference
            
            view.bind("padding(self, value: int | None = None) -> View") { argc, argv in
                PyBind.function(argc, argv, paddingModifier)
            }
            
            view.bind("align(self, aligment: str) -> View") { _, argv in
                PyAPI.returnOrThrow {
                    let aligment = try String.cast(argv, 1)
                    return AlignmentModifier(
                        horizontal: Alignment.horizontal(aligment),
                        vertical: Alignment.vertical(aligment)
                    )
                    .apply(argv)
                }
            }
            
            view.bind("overlay(self, views: View) -> View") { _, argv in
                PyAPI.returnOrThrow {
                    try py.tpobject(ZStack.pyType)?.call([argv, argv?[1]])
                }
            }
            
            view.bind("closable(self) -> View") { _, argv in
                PyAPI.returnOrThrow {
                    ClosableModifier().apply(argv)
                }
            }
            
            view.bind("font(self, style: str = 'body')") { argc, argv in
                PyBind.function(argc, argv, fontModifier)
            }
            
            view.bind("inspector(self, content: View) -> View") { argc, argv in
                PyBind.function(argc, argv, inspector)
            }
        }

        PyBind.module("audio", [
            AudioPlayer.self,
        ])
        
        PyBind.module("music", [
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

@MainActor
func paddingModifier(self: PyAPI.Reference, value: Int?) -> PyAPI.Reference? {
    AnyModifier { content in
        if let value {
            content.padding(CGFloat(value))
        } else {
            content.padding()
        }
    }
    .apply(self)
}

@MainActor
func fontModifier(self: PyAPI.Reference, style: String) -> PyAPI.Reference? {
    let fontStyle: Font.TextStyle = switch style {
    case "title": .title
    case "body": .body
    case "caption": .caption
    default: .body
    }
    
    return AnyModifier { content in
        content.font(.system(fontStyle))
    }
    .apply(self)
}
