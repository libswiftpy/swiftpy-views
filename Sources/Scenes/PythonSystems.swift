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

    /// The same frame, given time skipped before it too.
    internal func adding(_ seconds: Double) -> SceneContext {
        SceneContext(deltaTime: deltaTime + seconds, sceneID: sceneID, perform: perform)
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

    static func hasSteps(owner: String) -> Bool {
        steps.values.contains { $0.owner == owner }
    }

    /// Time skipped while Python was busy elsewhere, given to the next update.
    private static var skipped: Double = 0

    static func update(_ context: @autoclosure () -> SceneContext) {
        guard !steps.isEmpty else { return }
        // Waiting for Python would freeze the frame; RealityKit renders on, and
        // the steps catch up with the time skipped once it's free.
        if Interpreter.isBusyElsewhere {
            skipped += context().deltaTime
            return
        }
        var context = context()
        if skipped > 0 {
            context = context.adding(skipped)
            skipped = 0
        }
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
    }
}
