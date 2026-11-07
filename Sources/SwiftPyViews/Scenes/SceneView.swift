//
//  SceneView.swift
//  swiftpy-views
//

import Foundation
import RealityKit
import SwiftPy
import SwiftUI

/// A RealityKit scene, and the view showing it.
///
/// ```python
/// import scenes
///
/// scene = scenes.Scene()
/// scene.add(scenes.Entity.box(scenes.Vector3(0.2, 0.2, 0.2), color="red"))
/// scene
/// ```
@Scriptable("Scene", base: .View)
@MainActor
final class SceneView {
    typealias Entity = SceneEntity

    var entities: [Entity] { root.children.map(SceneEntity.wrapper) }

    internal let root = RealityKit.Entity()
    internal let camera: CameraControls

    /// Every scene, to find one from a system's context.
    private static let scenes = NSHashTable<SceneView>.weakObjects()

    /// camera: "orbit", "pan" or None. Has no effect on visionOS.
    init(camera: String? = "orbit") throws {
        switch camera {
        case "orbit": self.camera = .orbit
        case "pan": self.camera = .pan
        case nil: self.camera = .none
        case let camera?: throw PythonError.ValueError("unknown camera: \(camera)")
        }
        SceneRootComponent.registerComponent()
        root.components.set(SceneRootComponent())
        Self.scenes.add(self)
    }

    func add(_ entity: Entity) { root.addChild(entity.entity) }
    func remove(_ entity: Entity) { root.removeChild(entity.entity) }

    func find(_ name: String) -> Entity? {
        root.findEntity(named: name).map(SceneEntity.wrapper)
    }

    func body() -> AnyView {
        AnyView(SceneContent(model: self))
    }
}

extension SceneView {
    static func showing(_ sceneID: Int) -> SceneView? {
        scenes.allObjects.first { $0.root.scene.map { ObjectIdentifier($0).hashValue } == sceneID }
    }
}

private struct SceneContent: View {
    let model: SceneView
    @State private var height: CGFloat?

    var body: some View {
        RealityView { content in
            content.add(model.root)
            // Scripts have no lights yet, and it would render black.
            let light = DirectionalLight()
            light.light.intensity = 3000
            light.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(light)
            #if !os(visionOS)
            content.camera = .virtual
            content.cameraTarget = model.root
            #endif
        }
        #if !os(visionOS)
        .realityViewCameraControls(model.camera)
        #endif
        .realityViewLayoutBehavior(.centered)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { height = $0 }
        .frame(minHeight: height)
    }
}
