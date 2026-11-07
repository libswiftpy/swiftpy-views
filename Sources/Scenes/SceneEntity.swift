//
//  SceneEntity.swift
//  swiftpy-views
//

import Foundation
import RealityKit
import SwiftPy
import SwiftPyViews
import SwiftUI

/// An entity's transform. What it returns is live: changing
/// `entity.transform.translation.x` moves the entity. `copy()` detaches.
@Scriptable("Transform")
@MainActor
final class EntityTransform {
    var translation: Vector3 {
        get {
            Vector3(live: Live(
                get: { [entity] in entity.transform.translation },
                set: { [entity] in entity.transform.translation = $0 }
            ))
        }
        set { entity.transform.translation = newValue.simd }
    }

    var rotation: Quaternion {
        get {
            Quaternion(live: Live(
                get: { [entity] in entity.transform.rotation },
                set: { [entity] in entity.transform.rotation = $0 }
            ))
        }
        set { entity.transform.rotation = newValue.simd }
    }

    var scale: Vector3 {
        get {
            Vector3(live: Live(
                get: { [entity] in entity.transform.scale },
                set: { [entity] in entity.transform.scale = $0 }
            ))
        }
        set { entity.transform.scale = newValue.simd }
    }

    internal let entity: RealityKit.Entity

    internal init(entity: RealityKit.Entity) {
        self.entity = entity
    }
}

/// A scene's root, which Python never sees.
struct SceneRootComponent: Component {}

/// An object in a scene, with a transform, children and components.
@Scriptable("Entity")
@MainActor
final class SceneEntity {
    // As Python knows them, which is what its type stubs are written from.
    typealias Entity = SceneEntity
    typealias Transform = EntityTransform

    var name: String {
        get { entity.name }
        set { entity.name = newValue }
    }

    var isEnabled: Bool {
        get { entity.isEnabled }
        set { entity.isEnabled = newValue }
    }

    var transform: Transform { EntityTransform(entity: entity) }

    var children: [Entity] { entity.children.map(Self.wrapper) }

    var parent: Entity? {
        guard let parent = entity.parent, !parent.components.has(SceneRootComponent.self) else { return nil }
        return Self.wrapper(for: parent)
    }

    internal let entity: RealityKit.Entity
    /// The wrapper of each entity Python holds, so `scene.entities[0] is box`.
    internal static let wrappers = NSMapTable<RealityKit.Entity, SceneEntity>.weakToWeakObjects()

    init(name: String = "") {
        entity = RealityKit.Entity()
        entity.name = name
        Self.wrappers.setObject(self, forKey: entity)
    }

    internal init(wrapping entity: RealityKit.Entity) {
        self.entity = entity
        Self.wrappers.setObject(self, forKey: entity)
    }

    func add(_ child: Entity) { entity.addChild(child.entity) }
    func remove(_ child: Entity) { entity.removeChild(child.entity) }

    /// A copy with its children. Python components are shared with the original.
    func clone() -> Entity { SceneEntity(wrapping: entity.clone(recursive: true)) }

    static func box(size: Vector3, color: ColorValue = "white") throws -> Entity {
        try model(.generateBox(size: size.simd), color: color)
    }

    static func sphere(radius: Float, color: ColorValue = "white") throws -> Entity {
        try model(.generateSphere(radius: radius), color: color)
    }

    static func plane(size: Vector2, color: ColorValue = "white") throws -> Entity {
        try model(.generatePlane(width: size.x, depth: size.y), color: color)
    }

    /// A model from a file, such as a USDZ.
    static func load(path: String) async throws -> Entity {
        SceneEntity(wrapping: try await RealityKit.Entity(contentsOf: Path(path).url))
    }

    func _setComponent(_ index: Int, _ value: PyObject) {
        PythonComponents.set(index, value, on: entity)
    }

    func _component(_ index: Int) -> PyObject? {
        PythonComponents.value(index, on: entity)
    }

    func _removeComponent(_ index: Int) {
        PythonComponents.remove(index, from: entity)
    }

    func _componentValues() -> [PyObject] {
        PythonComponents.values(on: entity)
    }
}

extension SceneEntity {
    static func wrapper(for entity: RealityKit.Entity) -> SceneEntity {
        wrappers.object(forKey: entity) ?? SceneEntity(wrapping: entity)
    }

    private static func model(_ mesh: MeshResource, color: ColorValue) throws -> SceneEntity {
        let color = try SwiftUI.Color(pythonName: color.name)
        #if canImport(UIKit)
        let material = SimpleMaterial(color: UIColor(color), isMetallic: false)
        #else
        let material = SimpleMaterial(color: NSColor(color), isMetallic: false)
        #endif
        return SceneEntity(wrapping: ModelEntity(mesh: mesh, materials: [material]))
    }
}
