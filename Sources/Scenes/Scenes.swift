//
//  Scenes.swift
//  swiftpy-views
//

import SwiftPy
import SwiftPyViews

@MainActor
public enum Scenes {
    /// Registers `scenes`; `views` must be registered first.
    public static func initialize() {
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
                SceneCameraComponent.self,
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
        PyBind.module("scenes.components", in: .module)
    }

    /// Forgets the Python systems, all or a notebook's, for code that starts over:
    /// they live outside its namespace, and would go on running.
    public static func removeSystems(owner: String? = nil) {
        PythonSystems.removeAll(owner: owner)
    }

    public static func hasSystems(owner: String) -> Bool {
        PythonSystems.hasSteps(owner: owner)
    }
}
