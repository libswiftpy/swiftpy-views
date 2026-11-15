//
//  SceneView.swift
//  swiftpy-views
//

import Foundation
import RealityKit
import SwiftPy
import SwiftPyViews
import SwiftUI

/// A 3D scene, and the view showing it.
///
/// ```python
/// Scene(Entity.box(color="red"))
/// ```
@Scriptable("Scene", base: .View)
@Observable
@MainActor
final class SceneView {
    typealias Entity = SceneEntity

    /// How the camera follows gestures: a `CameraControl`, or its name, or None.
    /// Has no effect on visionOS, where the viewer moves instead.
    var cameraControl: CameraControlValue?

    var entities: [Entity] {
        root.children.filter { !$0.components.has(SceneHeartbeatComponent.self) }.map(SceneEntity.wrapper)
    }

    internal let root = RealityKit.Entity()
    /// The view's size in metres, while it's shown on visionOS.
    @ObservationIgnored internal var availableSize: Float?
    /// The views showing it, newest last. An entity has one parent, so only
    /// the newest holds the root; the rest show a placeholder.
    fileprivate var shownIn: [UUID] = []
    /// Counts camera components added or removed, for the view to look again.
    fileprivate var cameraChanges = 0

    /// Every scene, to find one from a system's context.
    private static let scenes = NSHashTable<SceneView>.weakObjects()

    /// entities: Entities to add.
    /// camera_control: How the camera follows gestures. Defaults to orbiting.
    init(entities: Unpack, cameraControl: CameraControlValue? = "orbit") throws {
        self.cameraControl = cameraControl
        SceneRootComponent.registerComponent()
        SceneHeartbeatComponent.registerComponent()
        root.components.set(SceneRootComponent())
        let heartbeat = RealityKit.Entity()
        heartbeat.components.set(SceneHeartbeatComponent())
        root.addChild(heartbeat)
        for object in entities.values {
            guard let entity = try? Entity.cast(object.reference) else {
                throw PythonError.TypeError("Scene takes entities, not \(object.typeName)")
            }
            add(entity)
        }
        Self.scenes.add(self)
    }

    func add(_ entity: Entity) {
        root.addChild(entity.entity)
        Self.cameraDidChange(on: root)
    }

    func remove(_ entity: Entity) {
        root.removeChild(entity.entity)
        Self.cameraDidChange(on: root)
    }

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
        // A new scene in the same place, as after a playground run, is a new
        // view: the old one wouldn't appear again to claim it.
        AnyView(SceneContent(model: self).id(ObjectIdentifier(self)))
    }
}

// Out of the class body, which the macro binds to Python.
extension SceneView {
    var holder: UUID? { shownIn.last }

    /// Whether an entity in it has a camera, which the view then shows from.
    var hasCamera: Bool {
        _ = cameraChanges
        return Self.containsCamera(root)
    }

    private static func containsCamera(_ entity: RealityKit.Entity) -> Bool {
        entity.components.has(PerspectiveCameraComponent.self) || entity.children.contains(where: containsCamera)
    }

    /// Tells the scene holding `entity`, if one does, that a camera came or went.
    static func cameraDidChange(on entity: RealityKit.Entity) {
        var top = entity
        while let parent = top.parent { top = parent }
        scenes.allObjects.first { $0.root === top }?.cameraChanges += 1
    }

    func show(in view: UUID) {
        shownIn.removeAll { $0 == view }
        shownIn.append(view)
    }

    func hide(from view: UUID) {
        shownIn.removeAll { $0 == view }
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
        // Gestures would fight the script's camera.
        if hasCamera { return .none }
        return switch cameraControl?.name {
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
    @Environment(\.isInWindow) private var isInWindow
    /// The fitted side: the width in a card, which is square, the shorter side in a window.
    @State private var height: CGFloat?
    @State private var id = UUID()

    var body: some View {
        // Only the holder has a RealityView: an empty one for each other place
        // costs a Metal layer, and enough of them fail to allocate.
        Group {
            if model.holder == id {
                realityView
            } else {
                Color.clear.overlay {
                    if model.holder != nil {
                        Label("Shown in another view", systemImage: "cube.transparent")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { model.show(in: id) }
        .onDisappear { model.hide(from: id) }
        // In a window it draws under the bars to the edges; fitting still uses
        // the safe area, measured outside this.
        .ignoresSafeArea(edges: isInWindow ? .all : [])
        // Copied: the transform is Sendable, the environment main-actor.
        .onGeometryChange(for: CGFloat.self, of: { [isInWindow] in isInWindow ? min($0.size.width, $0.size.height) : $0.size.width }) {
            height = $0
        }
        .frame(minHeight: isInWindow ? nil : height)
        .frame(maxWidth: .infinity, maxHeight: isInWindow ? .infinity : nil)
        // A window hands its whole space over, rather than scrolling a square.
        .fillsAvailableSpace()
    }

    private var realityView: some View {
        RealityView { content in
            // Added here, it moves from the view that held it before.
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
    }
}
