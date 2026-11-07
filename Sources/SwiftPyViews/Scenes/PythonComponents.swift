//
//  PythonComponents.swift
//  swiftpy-views
//

import RealityKit
import SwiftPy

/// A Python `Component` in RealityKit. Its sets and queries go by Swift type,
/// and there are as many of those as there are Python classes, so each class
/// gets a type built at run time from its index's bits: `B1<B0<...>>`.
protocol PythonComponentType: Component {
    var value: PyObject { get }
    init(_ value: PyObject)
}

struct PythonComponent: PythonComponentType {
    let value: PyObject
    init(_ value: PyObject) { self.value = value }
}

struct B0<Next: PythonComponentType>: PythonComponentType {
    let value: PyObject
    init(_ value: PyObject) { self.value = value }
}

struct B1<Next: PythonComponentType>: PythonComponentType {
    let value: PyObject
    init(_ value: PyObject) { self.value = value }
}

@MainActor
enum PythonComponents {
    private static var types: [Int: any PythonComponentType.Type] = [:]

    static func type(_ index: Int) -> any PythonComponentType.Type {
        if let type = types[index] { return type }
        var type: any PythonComponentType.Type = PythonComponent.self
        var bits = index
        while bits > 0 {
            type = nest(type, bit: bits & 1 == 1)
            bits >>= 1
        }
        register(type)
        types[index] = type
        return type
    }

    static func set(_ index: Int, _ value: PyObject, on entity: RealityKit.Entity) {
        set(type(index), value, on: entity)
    }

    static func value(_ index: Int, on entity: RealityKit.Entity) -> PyObject? {
        value(of: type(index), on: entity)
    }

    static func remove(_ index: Int, from entity: RealityKit.Entity) {
        remove(type(index), from: entity)
    }

    static func values(on entity: RealityKit.Entity) -> [PyObject] {
        types.keys.sorted().compactMap { value($0, on: entity) }
    }

    /// Entities with every component in `indices`, or all without any.
    static func query(_ indices: [Int]) -> EntityQuery {
        let predicates = indices.map { predicate(type($0)) }
        guard let first = predicates.first else { return EntityQuery() }
        return EntityQuery(where: predicates.dropFirst().reduce(first) { $0 && $1 })
    }

    private static func nest<T: PythonComponentType>(_: T.Type, bit: Bool) -> any PythonComponentType.Type {
        bit ? B1<T>.self : B0<T>.self
    }

    private static func register<T: PythonComponentType>(_: T.Type) {
        T.registerComponent()
    }

    private static func set<T: PythonComponentType>(_: T.Type, _ value: PyObject, on entity: RealityKit.Entity) {
        entity.components.set(T(value))
    }

    private static func value<T: PythonComponentType>(of _: T.Type, on entity: RealityKit.Entity) -> PyObject? {
        entity.components[T.self]?.value
    }

    private static func remove<T: PythonComponentType>(_: T.Type, from entity: RealityKit.Entity) {
        entity.components.remove(T.self)
    }

    private static func predicate<T: PythonComponentType>(_: T.Type) -> QueryPredicate<RealityKit.Entity> {
        .has(T.self)
    }
}
