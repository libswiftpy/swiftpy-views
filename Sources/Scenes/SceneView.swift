//
//  SceneView.swift
//  swiftpy-views
//

import Foundation
import RealityKit
import SwiftPy
import SwiftPyViews
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
@Observable
@MainActor
final class SceneView {
    typealias Entity = SceneEntity

    /// How the camera follows gestures: a `CameraControl`, or its name, or None.
    /// Has no effect on visionOS, where the viewer moves instead.
    var cameraControl: CameraControlValue?

    var entities: [Entity] { root.children.map(SceneEntity.wrapper) }

    internal let root = RealityKit.Entity()
    /// The view's size in metres, while it's shown on visionOS.
    @ObservationIgnored internal var availableSize: Float?

    /// Every scene, to find one from a system's context.
    private static let scenes = NSHashTable<SceneView>.weakObjects()

    /// camera_control: How the camera follows gestures. Defaults to orbiting.
    init(cameraControl: CameraControlValue? = "orbit") {
        self.cameraControl = cameraControl
        SceneRootComponent.registerComponent()
        root.components.set(SceneRootComponent())
        Self.scenes.add(self)
    }

    func add(_ entity: Entity) { root.addChild(entity.entity) }
    func remove(_ entity: Entity) { root.removeChild(entity.entity) }

    func find(_ name: String) -> Entity? {
        root.findEntity(named: name).map(SceneEntity.wrapper)
    }

    /// Scales the content down to fit the view, as it is now. Has no effect until
    /// the scene is shown, or where the camera frames it, off visionOS.
    func fitContent() {
        guard let availableSize else { return }
        let radius = root.visualBounds(relativeTo: root).boundingRadius
        root.scale = .init(repeating: Self.fitScale(radius: radius, available: availableSize))
    }

    func body() -> AnyView {
        AnyView(SceneContent(model: self))
    }
}

extension SceneView {
    /// By the bounding sphere, so content turning in place stays inside.
    /// Only ever down: a metre is a metre where it fits.
    static func fitScale(radius: Float, available: Float) -> Float {
        guard radius > 0, available > 0 else { return 1 }
        return min(available / (2 * radius), 1)
    }

    static func showing(_ sceneID: Int) -> SceneView? {
        scenes.allObjects.first { $0.root.scene.map { ObjectIdentifier($0).hashValue } == sceneID }
    }
}

/// `scenes.CameraControlValue`: a `CameraControl`, or its name.
struct CameraControlValue: StrEnumValue {
    static let enumName = "CameraControl"
    static let moduleName = "scenes"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }
}

@MainActor extension CameraControlValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool {
        String.isConvertible(reference)
            && ["orbit", "pan", "tilt", "dolly"].contains(String.fromPython(reference))
    }
}

#if !os(visionOS)
private extension SceneView {
    var cameraControls: CameraControls {
        switch cameraControl?.name {
        case "orbit": .orbit
        case "pan": .pan
        case "tilt": .tilt
        case "dolly": .dolly
        default: .none
        }
    }
}
#endif

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
        } update: { content in
            #if os(visionOS)
            guard let height else { return }
            let size = Size3D(width: height, height: height, depth: 0)
            model.availableSize = abs(content.convert(size, from: .local, to: .scene).x)
            #endif
        }
        #if !os(visionOS)
        .realityViewCameraControls(model.cameraControls)
        #endif
        .realityViewLayoutBehavior(.centered)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { height = $0 }
        .frame(minHeight: height)
    }
}
