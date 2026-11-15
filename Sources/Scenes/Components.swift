//
//  Components.swift
//  swiftpy-views
//

import RealityKit
import SwiftPy
import SwiftPyViews

/// RealityKit's own components, for `scenes.components`, by the name Python
/// classes give in `_native`: what `context.query` asks for them by.
@MainActor
enum NativeComponents {
    static func predicate(_ name: String) -> QueryPredicate<RealityKit.Entity>? {
        switch name {
        case "PerspectiveCameraComponent": .has(RealityKit.PerspectiveCameraComponent.self)
        default: registered[name]
        }
    }

    static var registered: [String: QueryPredicate<RealityKit.Entity>] = [:]
}

/// For other packages' components on `scenes` entities.
@MainActor
public enum SceneEntities {
    /// The RealityKit entity behind a `scenes.Entity`.
    public static func entity(_ object: PyObject) -> RealityKit.Entity? {
        SceneEntity(object.reference)?.entity
    }

    /// The `scenes.Entity` for a RealityKit entity.
    public static func object(_ entity: RealityKit.Entity) throws(PythonError) -> PyObject {
        try SceneEntity.wrapper(for: entity).toPython()
    }

    /// Lets `context.query` find a component whose Python class has `_native = name`.
    public static func registerComponent(_ name: String, predicate: QueryPredicate<RealityKit.Entity>) {
        NativeComponents.registered[name] = predicate
    }
}

/// A perspective camera: the scene's view shows what it sees, from its
/// entity's place and turn. Has no effect on visionOS, where the viewer moves.
///
/// One made on its own holds its values; one read from an entity, with
/// `entity.components[PerspectiveCameraComponent]`, is live: changing it
/// changes the entity's camera.
@Scriptable("PerspectiveCameraComponent")
@MainActor
final class SceneCameraComponent {
    typealias Entity = SceneEntity

    /// The field of view, in degrees.
    var fov: Float {
        get { component.fieldOfViewInDegrees }
        set { component.fieldOfViewInDegrees = newValue }
    }

    /// The nearest distance it shows, in metres.
    var near: Float {
        get { component.near }
        set { component.near = newValue }
    }

    /// The farthest distance it shows, in metres; None for no limit.
    var far: Float? {
        get { component.far.isFinite ? component.far : nil }
        set { component.far = newValue ?? .infinity }
    }

    /// Which side `fov` spans: a `FieldOfViewOrientation`, or its name.
    var fovOrientation: FieldOfViewOrientationValue {
        get { component.fieldOfViewOrientation == .horizontal ? "horizontal" : "vertical" }
        set { component.fieldOfViewOrientation = newValue.name == "horizontal" ? .horizontal : .vertical }
    }

    internal var live: Live<RealityKit.PerspectiveCameraComponent>?
    internal var stored = RealityKit.PerspectiveCameraComponent()

    /// fov: The field of view, in degrees. Defaults to 60.
    /// near: The nearest distance it shows, in metres. Defaults to 0.01.
    /// far: The farthest distance it shows, in metres. Defaults to None, for no limit.
    /// fov_orientation: Which side `fov` spans, `FieldOfViewOrientation.VERTICAL` or `HORIZONTAL`. Defaults to vertical.
    init(fov: Float = 60, near: Float = 0.01, far: Float? = nil, fovOrientation: FieldOfViewOrientationValue = "vertical") {
        self.fov = fov
        self.near = near
        self.far = far
        self.fovOrientation = fovOrientation
    }

    /// A copy that isn't live.
    func copy() -> SceneCameraComponent {
        let copy = SceneCameraComponent()
        copy.stored = component
        return copy
    }

    func _apply(_ entity: Entity) {
        entity.entity.components.set(component)
        SceneView.cameraDidChange(on: entity.entity)
    }

    static func _read(_ entity: Entity) -> SceneCameraComponent? {
        let entity = entity.entity
        guard entity.components.has(RealityKit.PerspectiveCameraComponent.self) else { return nil }
        let camera = SceneCameraComponent()
        camera.live = Live(
            get: { [entity] in entity.components[RealityKit.PerspectiveCameraComponent.self] ?? .init() },
            set: { [entity] in entity.components.set($0) }
        )
        return camera
    }

    static func _remove(_ entity: Entity) {
        entity.entity.components.remove(RealityKit.PerspectiveCameraComponent.self)
        SceneView.cameraDidChange(on: entity.entity)
    }
}

extension SceneCameraComponent {
    var component: RealityKit.PerspectiveCameraComponent {
        get { live?.get() ?? stored }
        set {
            if let live { live.set(newValue) } else { stored = newValue }
        }
    }
}

/// `scenes.components.FieldOfViewOrientation`, or its name.
struct FieldOfViewOrientationValue: StrEnumValue {
    static let enumName = "FieldOfViewOrientation"
    static let moduleName = "scenes.components"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }
}

@MainActor extension FieldOfViewOrientationValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool {
        String.isConvertible(reference) && ["vertical", "horizontal"].contains(String.fromPython(reference))
    }
}
