//
//  Scenes.swift
//  swiftpy-views
//

import SwiftPy
import SwiftPyViews

@MainActor
public enum Scenes {
    /// Registers `scenes`, in debug builds only for now; `views` must be
    /// registered first.
    public static func initialize() {
        #if DEBUG
        PyBind.module("_scenes", docs: "Native scenes.") { module in
            module.classes(
                Vector2.self,
                Vector3.self,
                Vector4.self,
                Quaternion.self,
                EntityTransform.self,
                SceneEntity.self,
                SceneContext.self,
                SceneView.self,
            )

            module.def("_register_system(name: str, step: Callable) -> None") { argc, argv in
                PyBind.function(argc, argv) { (name: String, step: Callback) -> Void in
                    PythonSystems.register(name, step: step)
                }
            }

            module.def("_unregister_system(name: str) -> None") { argc, argv in
                PyBind.function(argc, argv) { (name: String) -> Void in
                    PythonSystems.unregister(name)
                }
            }
        }
        PyBind.module("scenes", in: .module)
        #endif
    }

    /// Forgets every Python system, for an interpreter that starts over: they
    /// live outside `__main__`, and would go on running in the next notebook's scenes.
    public static func removeSystems() {
        PythonSystems.removeAll()
    }
}
