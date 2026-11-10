//
//  PythonSystems.swift
//  swiftpy-views
//

import Foundation
import RealityKit
import SwiftPy
import SwiftPyViews

/// What a system's `update` gets each frame.
@Scriptable
@MainActor
final class SceneContext {
    typealias Entity = SceneEntity
    typealias Scene = SceneView

    /// Seconds since the last update.
    let deltaTime: Double
    /// The scene being updated.
    var scene: Scene? { SceneView.showing(sceneID) }

    var _sceneId: Int { sceneID }

    internal let sceneID: Int
    internal let perform: (EntityQuery) -> [RealityKit.Entity]

    internal init(deltaTime: Double, sceneID: Int, perform: @escaping (EntityQuery) -> [RealityKit.Entity]) {
        self.deltaTime = deltaTime
        self.sceneID = sceneID
        self.perform = perform
    }

    func _query(_ indices: [Int]) -> [Entity] {
        perform(PythonComponents.query(indices)).map(SceneEntity.wrapper)
    }
}

/// Python's systems. RealityKit can't unregister a system and makes one per
/// scene, so one driver stays registered and runs whichever are listed.
@MainActor
enum PythonSystems {
    private static var steps: [String: Callback] = [:]
    private static var isDriverRegistered = false

    static func register(_ name: String, step: Callback) {
        steps[name] = step
        guard !isDriverRegistered else { return }
        isDriverRegistered = true
        PythonSystemDriver.registerSystem()
    }

    static func unregister(_ name: String) {
        steps[name] = nil
    }

    static func removeAll(owner: String? = nil) {
        steps = steps.filter { owner != nil && $0.value.owner != owner }
    }

    static var isEmpty: Bool { steps.isEmpty }

    static func hasSteps(owner: String) -> Bool {
        steps.values.contains { $0.owner == owner }
    }

    static func update(_ context: @autoclosure () -> SceneContext) {
        guard !steps.isEmpty else { return }
        // Never skipped while Python is busy elsewhere: RealityKit stops drawing
        // a frame that changes nothing, which froze the scene until it was moved.
        let context = context()
        // A copy: a step that fails unregisters itself.
        for step in Array(steps.values) {
            step.callback(with: context)
        }
    }
}

private struct PythonSystemDriver: System {
    init(scene: RealityKit.Scene) {}

    mutating func update(context: SceneUpdateContext) {
        PythonSystems.update(SceneContext(
            deltaTime: context.deltaTime,
            sceneID: ObjectIdentifier(context.scene).hashValue
        ) { query in
            Array(context.entities(matching: query, updatingSystemWhen: .rendering))
        })
        // A change every frame, so RealityKit draws the next one: a step that
        // changed nothing, as with no time elapsed, left the scene stopped.
        guard !PythonSystems.isEmpty else { return }
        let heartbeats = EntityQuery(where: .has(SceneHeartbeatComponent.self))
        for heartbeat in context.entities(matching: heartbeats, updatingSystemWhen: .rendering) {
            heartbeat.position.x = heartbeat.position.x == 0 ? 1e-6 : 0
        }
    }
}
