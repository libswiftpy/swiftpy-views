//
//  ScenesTests.swift
//  swiftpy-views
//

import RealityKit
import Testing
@testable import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct ScenesTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("""
        from scenes import *
        import scenes

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    /// As text, as `Interpreter.evaluate` only returns what's already that type.
    private func evaluate(_ expression: String) -> String? {
        Interpreter.evaluate("str(\(expression))")
    }

    private func close(_ expression: String, _ expected: Double) -> Bool {
        evaluate(expression).flatMap(Double.init).map { abs($0 - expected) < 0.0001 } ?? false
    }

    @Test func comesFromItsOwnModule() {
        #expect(evaluate("Entity.__module__") == "scenes")
        #expect(evaluate("Scene.__name__") == "Scene")
        #expect(evaluate("Transform.__name__") == "Transform")
    }

    /// Written from the Swift names, these would all be `Any`.
    @Test func itsStubUsesPythonsNames() async {
        await Interpreter.run("""
        import json, interpreter
        _stub = json.loads(interpreter._stubs())['scenes.pyi']
        """)
        #expect(evaluate("'SceneEntity' in _stub") == "False")
        #expect(evaluate("'def box(size: Vector3, color: ColorValue=\\'white\\') -> Entity' in _stub") == "True")
        #expect(evaluate("'components: Components' in _stub") == "True")
        #expect(evaluate("'def query(self, *components: type[Component]) -> Iterator[Entity]' in _stub") == "True")
        #expect(evaluate("'@classmethod' in _stub") == "True")
    }

    @Test func vectorsAreMadeAndRead() async {
        await Interpreter.run("""
        _a = Vector3(1, 2, 3)
        _z = Vector2.zero()
        _o = Vector3.one()
        """)
        #expect(close("_a.y", 2))
        #expect(close("_z.x", 0))
        #expect(close("_o.z", 1))
        #expect(evaluate("repr(Vector2(1, 2))") == "Vector2(1.0, 2.0)")
    }

    @Test func vectorsHaveOperators() async {
        await Interpreter.run("""
        _a = Vector3(1, 2, 3)
        _sum = _a + Vector3.one()
        _difference = _a - Vector3.one()
        _scaled = _a * 2
        _left = 2 * _a
        _half = _a / 2
        _minus = -_a
        """)
        #expect(close("_sum.x", 2))
        #expect(close("_difference.z", 2))
        #expect(close("_scaled.y", 4))
        #expect(close("_left.y", 4))
        #expect(close("_half.z", 1.5))
        #expect(close("_minus.x", -1))
        #expect(evaluate("Vector3(1, 2, 3) == _a") == "True")
        #expect(close("Vector3(3, 4, 0).length()", 5))
        #expect(close("Vector3(1, 0, 0).cross(Vector3(0, 1, 0)).z", 1))
    }

    @Test func aMadeVectorIsAReference() async {
        await Interpreter.run("""
        _a = Vector3(1, 2, 3)
        _b = _a
        _b.x += 3
        """)
        #expect(close("_a.x", 4))
    }

    @Test func aTransformsVectorsAreLive() async {
        await Interpreter.run("""
        _player = Entity("player")
        _player.transform.translation.x += 3
        _player.transform.scale.y = 2
        _alias = _player.transform.translation
        _alias.z = 5
        _copy = _player.transform.translation.copy()
        _copy.x = 100
        """)
        #expect(close("_player.transform.translation.x", 3))
        #expect(close("_player.transform.translation.z", 5))
        #expect(close("_player.transform.scale.y", 2))
    }

    @Test func assigningAVectorCopiesIt() async {
        await Interpreter.run("""
        _a = Entity()
        _b = Entity()
        _a.transform.translation = Vector3(1, 2, 3)
        _b.transform.translation = _a.transform.translation
        _a.transform.translation.x = 9
        """)
        #expect(close("_b.transform.translation.x", 1))
    }

    @Test func rotationsCompose() async {
        await Interpreter.run("""
        import math
        _quarter = Quaternion.from_axis_angle(Vector3.up(), math.pi / 2)
        _turned = (_quarter * _quarter).rotate(Vector3(1, 0, 0))
        """)
        #expect(close("_turned.x", -1))
    }

    @Test func aSceneHoldsItsEntities() async {
        await Interpreter.run("""
        _scene = Scene()
        _box = Entity.box(Vector3(1, 1, 1), color="red")
        _box.name = "box"
        _child = Entity("child")
        _box.add(_child)
        _scene.add(_box)
        """)
        #expect(evaluate("_scene.entities[0] is _box") == "True")
        #expect(evaluate("_scene.find('child') is _child") == "True")
        #expect(evaluate("_child.parent is _box") == "True")
        #expect(evaluate("_box.parent") == "None")
        #expect(evaluate("_box.children[0] is _child") == "True")

        await Interpreter.run("_scene.remove(_box)")
        #expect(evaluate("len(_scene.entities)") == "0")
    }

    @Test func badArgumentsAreRefused() {
        #expect(evaluate("_raised(lambda: Scene(camera='spin'))") == "ValueError")
        #expect(evaluate("_raised(lambda: Entity.box(Vector3.one(), color='nope'))") == "ValueError")
        #expect(evaluate("_raised(lambda: Entity().components.set(3))") == "TypeError")
    }

    @Test func componentsAreKeptByClass() async {
        await Interpreter.run("""
        class _A(Component):
            value = 3

        class _B(Component):
            pass

        _entity = Entity()
        _a = _A()
        _entity.components.set(_a)
        _entity.components.set(_B())
        """)
        #expect(evaluate("_entity.components[_A] is _a") == "True")
        #expect(evaluate("_entity.components[_A].value") == "3")
        #expect(evaluate("_A in _entity.components") == "True")
        #expect(evaluate("len(_entity.components)") == "2")

        await Interpreter.run("_entity.components.remove(_A)")
        #expect(evaluate("_A in _entity.components") == "False")
        #expect(evaluate("_entity.components.get(_A)") == "None")
        #expect(evaluate("_raised(lambda: _entity.components[_A])") == "KeyError")
    }

    @Test func aCardsRerunFindsItsComponents() async {
        await Interpreter.run("""
        class _Rerun(Component):
            pass

        _kept = Entity()
        _kept.components.set(_Rerun())

        class _Rerun(Component):
            pass
        """)
        #expect(evaluate("_Rerun in _kept.components") == "True")
    }

    @Test func aSystemUpdatesEachFrame() async {
        await Interpreter.run("""
        _updates = []
        class _Counter(System):
            def update(self, context):
                _updates.append(context.delta_time)

        _Counter.register()
        """)
        let context = SceneContext(deltaTime: 0.5, sceneID: 1) { _ in [] }
        PythonSystems.update(context)
        PythonSystems.update(context)
        #expect(evaluate("_updates") == "[0.5, 0.5]")

        await Interpreter.run("""
        class _Counter(System):
            def update(self, context):
                _updates.append('replaced')

        _Counter.register()
        """)
        PythonSystems.update(context)
        #expect(evaluate("_updates[-1]") == "replaced")
        #expect(evaluate("len(_updates)") == "3")

        await Interpreter.run("_Counter.unregister()")
        PythonSystems.update(context)
        #expect(evaluate("len(_updates)") == "3")
    }

    @Test func aResetRemovesSystems() async {
        await Interpreter.run("""
        _kept = []
        class _Old(System):
            def update(self, context):
                _kept.append(1)

        _Old.register()
        """)
        let context = SceneContext(deltaTime: 0, sceneID: 4) { _ in [] }
        PythonSystems.update(context)
        removeSceneSystems()
        PythonSystems.update(context)
        #expect(evaluate("len(_kept)") == "1")
    }

    @Test func aFailingSystemIsUnregistered() async {
        await Interpreter.run("""
        _runs = []
        class _Failing(System):
            def update(self, context):
                _runs.append(1)
                raise ValueError('nope')

        _Failing.register()
        """)
        let context = SceneContext(deltaTime: 0, sceneID: 2) { _ in [] }
        PythonSystems.update(context)
        PythonSystems.update(context)
        #expect(evaluate("len(_runs)") == "1")
    }

    @Test func queriesFindEntitiesByTheirComponents() async {
        await Interpreter.run("""
        class _Q(Component):
            pass

        class _R(Component):
            pass

        _one = Entity()
        _one.components.set(_Q())
        _both = Entity()
        _both.components.set(_Q())
        _both.components.set(_R())
        _none = Entity()
        _found = []

        class _Finder(System):
            def update(self, context):
                _found.append(len(list(context.query(_Q))))
                _found.append(len(list(context.query(_Q, _R))))

        _Finder.register()
        """)
        let view = ARView(frame: .zero)
        let anchor = AnchorEntity()
        for name in ["_one", "_both", "_none"] {
            let wrapper: SceneEntity? = py.module("__main__")?[dynamicMember: name].flatMap { SceneEntity($0) }
            if let wrapper { anchor.addChild(wrapper.entity) }
        }
        view.scene.addAnchor(anchor)

        PythonSystems.update(SceneContext(deltaTime: 0, sceneID: 3) { Array(view.scene.performQuery($0)) })
        await Interpreter.run("_Finder.unregister()")
        // RealityKit may run a frame of its own while this waits.
        #expect(evaluate("_found[:2]") == "[2, 1]")
    }
}
