// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import SwiftPy
import HighlightSwift

public struct PythonWindows: Scene {
    public init() {
        PyBind.module("views") { module in
            module.classes(
                Views.self,
                
                Alignment.self,
                
                Button.self,
                CodeView.self,
                Text.self,
                Thumbnail.self,
                Image.self,
                Model3D.self,

                Group.self,
                HStack.self,
                ScrollView.self,
                VStack.self,
                ZStack.self,
                Section.self,
                SplitView.self,
                OutlineGroup.self,

                InspectorModifier.self,
                ToolbarModifier.self,
                AlignmentModifier.self,
                
                Window.self,
            )
            
            let view = PyObject(AnyView.pyTypeObject)!
            
            view.def("padding(self, value: int | None = None) -> View") { argc, argv in
                PyBind.function(argc, argv, paddingModifier)
            }
            
            view.def("align(self, aligment: str) -> View") { argc, argv in
                PyBind.function(argc, argv, AlignmentModifier.init)
            }
            
            view.def("overlay(self, *views) -> View") { argc, argv in
                PyBind.function(argc, argv) { (view: PyObject, content: PyTuple) in
                    var views = content
                    views.values.insert(view, at: 0)
                    return ZStack(views: views)
                }
            }
            
            view.def("closable(self) -> View") { argc, argv in
                PyBind.function(argc, argv) { (view: AnyView) in
                    AnyView(view.modifier(ToolbarCloseModifier()))
                }
            }
            
            view.def("font(self, style: str = 'body')") { argc, argv in
                PyBind.function(argc, argv, fontModifier)
            }
            
            view.def("inspector(self, content: View) -> View") { argc, argv in
                PyBind.function(argc, argv, InspectorModifier.init)
            }

            view.def("toolbar(self, content: View) -> View") { argc, argv in
                PyBind.function(argc, argv, ToolbarModifier.init)
            }
        }

        PyBind.module("audio") { module in
            module.class(AudioPlayer.self)
        }
        
        PyBind.module("music") { module in
            module.classes(
                MusicPlayer.self,
                Song.self,
            )
        }
        
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

@MainActor
func paddingModifier(self: AnyView, value: Int?) -> AnyView {
    if let value {
        AnyView(erasing: self.padding(CGFloat(value)))
    } else {
        AnyView(erasing: self.padding())
    }
}

@MainActor
func fontModifier(self: AnyView, style: String) -> AnyView {
    let fontStyle: Font.TextStyle = switch style {
    case "title": .title
    case "body": .body
    case "caption": .caption
    default: .body
    }
    return AnyView(erasing: self.font(.system(fontStyle)))
}
