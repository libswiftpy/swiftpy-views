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
//                ScrollView.self,
//                VStack.self,
//                ZStack.self,
                Section.self,
//                SplitView.self,
//                OutlineGroup.self,

//                InspectorModifier.self,
//                ToolbarModifier.self,
                
                Window.self,
            )
            
            let view = PyObject(AnyView.pyTypeObject)!
            
//            view.def("padding(self, value: int | None = None) -> View") { argc, argv in
//                PyBind.function(argc, argv) { (view: PyObject, value: Int?) in
//                    let view = view.asView?.padding(value.map(CGFloat.init))
//                    return AnyView(erasing: view)
//                }
//            }
            
//            view.def("align(self, aligment: str) -> View") { _, argv in
//                PyAPI.return {
//                    let aligment = try String.cast(argv, 1)
//                    return AlignmentModifier(
//                        horizontal: Alignment.horizontal(aligment),
//                        vertical: Alignment.vertical(aligment)
//                    )
//                    .apply(argv)
//                }
//            }
            
//            view.def("overlay(self, views: View) -> View") { _, argv in
//                PyAPI.return {
//                    try py.retain(py.tpobject(ZStack.pyType))?(argv, argv?[1])
//                }
//            }
            
            view.def("closable(self) -> View") { argc, argv in
                PyBind.function(argc, argv) { (view: AnyView) in
                    AnyView(view.modifier(ToolbarCloseModifier()))
                }
            }
            
//            view.def("font(self, style: str = 'body')") { argc, argv in
//                PyBind.function(argc, argv, fontModifier)
//            }
            
//            view.def("inspector(self, content: View) -> View") { argc, argv in
//                PyBind.function(argc, argv, inspector)
//            }
            
//            view.def("toolbar(self, content: View) -> View") { argc, argv in
//                PyBind.function(argc, argv, toolbar)
//            }
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

//@MainActor
//func paddingModifier(self: PyAPI.Reference, value: Int?) -> PyObject? {
//    AnyModifier { content in
//        if let value {
//            content.padding(CGFloat(value))
//        } else {
//            content.padding()
//        }
//    }
//    .apply(self)
//}

//@MainActor
//func fontModifier(self: PyAPI.Reference, style: String) -> PyObject? {
//    let fontStyle: Font.TextStyle = switch style {
//    case "title": .title
//    case "body": .body
//    case "caption": .caption
//    default: .body
//    }
//    
//    return AnyModifier { content in
//        content.font(.system(fontStyle))
//    }
//    .apply(self)
//}
