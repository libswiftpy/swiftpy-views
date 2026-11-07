//
//  Vectors.swift
//  swiftpy-views
//

import simd
import SwiftPy

/// Where a live vector reads and writes.
struct Live<Value> {
    let get: @MainActor () -> Value
    let set: @MainActor (Value) -> Void
}

/// A vector. One from a ``Transform`` is live: changing it moves its entity.
@Scriptable
@MainActor
final class Vector2: @MainActor CustomStringConvertible {
    var x: Float {
        get { simd.x }
        set {
            var value = simd
            value.x = newValue
            simd = value
        }
    }
    var y: Float {
        get { simd.y }
        set {
            var value = simd
            value.y = newValue
            simd = value
        }
    }

    internal var live: Live<SIMD2<Float>>?
    internal var stored: SIMD2<Float>

    init(x: Float = 0, y: Float = 0) {
        stored = SIMD2<Float>(x, y)
    }

    static func zero() -> Vector2 { Vector2(simd: .zero) }
    static func one() -> Vector2 { Vector2(simd: .one) }

    func length() -> Float { simd_length(simd) }
    func normalized() -> Vector2 { Vector2(simd: simd_normalize(simd)) }
    func dot(_ other: Vector2) -> Float { simd_dot(simd, other.simd) }
    func __add__(_ other: Vector2) -> Vector2 { Vector2(simd: simd + other.simd) }
    func __sub__(_ other: Vector2) -> Vector2 { Vector2(simd: simd - other.simd) }
    func __mul__(_ scale: Float) -> Vector2 { Vector2(simd: simd * scale) }
    func __rmul__(_ scale: Float) -> Vector2 { Vector2(simd: simd * scale) }
    func __truediv__(_ scale: Float) -> Vector2 { Vector2(simd: simd / scale) }
    func __neg__() -> Vector2 { Vector2(simd: -simd) }
    func __eq__(_ other: Vector2) -> Bool { simd == other.simd }

    /// A detached copy, which changes nothing else.
    func copy() -> Vector2 { Vector2(simd: simd) }
    internal var description: String { "Vector2(\(x), \(y))" }
}

extension Vector2 {
    convenience init(simd: SIMD2<Float>) {
        self.init()
        stored = simd
    }

    convenience init(live: Live<SIMD2<Float>>) {
        self.init()
        self.live = live
    }

    var simd: SIMD2<Float> {
        get { live?.get() ?? stored }
        set {
            if let live { live.set(newValue) } else { stored = newValue }
        }
    }
}

/// A vector. One from a ``Transform`` is live: changing it moves its entity.
@Scriptable
@MainActor
final class Vector3: @MainActor CustomStringConvertible {
    var x: Float {
        get { simd.x }
        set {
            var value = simd
            value.x = newValue
            simd = value
        }
    }
    var y: Float {
        get { simd.y }
        set {
            var value = simd
            value.y = newValue
            simd = value
        }
    }
    var z: Float {
        get { simd.z }
        set {
            var value = simd
            value.z = newValue
            simd = value
        }
    }

    internal var live: Live<SIMD3<Float>>?
    internal var stored: SIMD3<Float>

    init(x: Float = 0, y: Float = 0, z: Float = 0) {
        stored = SIMD3<Float>(x, y, z)
    }

    static func zero() -> Vector3 { Vector3(simd: .zero) }
    static func one() -> Vector3 { Vector3(simd: .one) }

    func length() -> Float { simd_length(simd) }
    func normalized() -> Vector3 { Vector3(simd: simd_normalize(simd)) }
    func dot(_ other: Vector3) -> Float { simd_dot(simd, other.simd) }
    func __add__(_ other: Vector3) -> Vector3 { Vector3(simd: simd + other.simd) }
    func __sub__(_ other: Vector3) -> Vector3 { Vector3(simd: simd - other.simd) }
    func __mul__(_ scale: Float) -> Vector3 { Vector3(simd: simd * scale) }
    func __rmul__(_ scale: Float) -> Vector3 { Vector3(simd: simd * scale) }
    func __truediv__(_ scale: Float) -> Vector3 { Vector3(simd: simd / scale) }
    func __neg__() -> Vector3 { Vector3(simd: -simd) }
    func __eq__(_ other: Vector3) -> Bool { simd == other.simd }
    func cross(_ other: Vector3) -> Vector3 { Vector3(simd: simd_cross(simd, other.simd)) }

    static func up() -> Vector3 { Vector3(simd: [0, 1, 0]) }
    static func forward() -> Vector3 { Vector3(simd: [0, 0, -1]) }
    static func right() -> Vector3 { Vector3(simd: [1, 0, 0]) }

    /// A detached copy, which changes nothing else.
    func copy() -> Vector3 { Vector3(simd: simd) }
    internal var description: String { "Vector3(\(x), \(y), \(z))" }
}

extension Vector3 {
    convenience init(simd: SIMD3<Float>) {
        self.init()
        stored = simd
    }

    convenience init(live: Live<SIMD3<Float>>) {
        self.init()
        self.live = live
    }

    var simd: SIMD3<Float> {
        get { live?.get() ?? stored }
        set {
            if let live { live.set(newValue) } else { stored = newValue }
        }
    }
}

/// A vector. One from a ``Transform`` is live: changing it moves its entity.
@Scriptable
@MainActor
final class Vector4: @MainActor CustomStringConvertible {
    var x: Float {
        get { simd.x }
        set {
            var value = simd
            value.x = newValue
            simd = value
        }
    }
    var y: Float {
        get { simd.y }
        set {
            var value = simd
            value.y = newValue
            simd = value
        }
    }
    var z: Float {
        get { simd.z }
        set {
            var value = simd
            value.z = newValue
            simd = value
        }
    }
    var w: Float {
        get { simd.w }
        set {
            var value = simd
            value.w = newValue
            simd = value
        }
    }

    internal var live: Live<SIMD4<Float>>?
    internal var stored: SIMD4<Float>

    init(x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 0) {
        stored = SIMD4<Float>(x, y, z, w)
    }

    static func zero() -> Vector4 { Vector4(simd: .zero) }
    static func one() -> Vector4 { Vector4(simd: .one) }

    /// A detached copy, which changes nothing else.
    func copy() -> Vector4 { Vector4(simd: simd) }
    internal var description: String { "Vector4(\(x), \(y), \(z), \(w))" }
}

extension Vector4 {
    convenience init(simd: SIMD4<Float>) {
        self.init()
        stored = simd
    }

    convenience init(live: Live<SIMD4<Float>>) {
        self.init()
        self.live = live
    }

    var simd: SIMD4<Float> {
        get { live?.get() ?? stored }
        set {
            if let live { live.set(newValue) } else { stored = newValue }
        }
    }
}

/// A rotation. One from a ``Transform`` is live, as a vector is.
@Scriptable
@MainActor
final class Quaternion: @MainActor CustomStringConvertible {
    var x: Float {
        get { simd.imag.x }
        set { simd.imag.x = newValue }
    }
    var y: Float {
        get { simd.imag.y }
        set { simd.imag.y = newValue }
    }
    var z: Float {
        get { simd.imag.z }
        set { simd.imag.z = newValue }
    }
    var w: Float {
        get { simd.real }
        set { simd.real = newValue }
    }

    internal var live: Live<simd_quatf>?
    internal var stored: simd_quatf

    init(x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 1) {
        stored = simd_quatf(ix: x, iy: y, iz: z, r: w)
    }

    static func identity() -> Quaternion { Quaternion() }

    /// angle: In radians.
    static func fromAxisAngle(_ axis: Vector3, _ angle: Float) -> Quaternion {
        Quaternion(simd: simd_quatf(angle: angle, axis: simd_normalize(axis.simd)))
    }

    func copy() -> Quaternion { Quaternion(simd: simd) }
    func rotate(_ vector: Vector3) -> Vector3 { Vector3(simd: simd.act(vector.simd)) }
    func __mul__(_ other: Quaternion) -> Quaternion { Quaternion(simd: simd * other.simd) }
    internal var description: String { "Quaternion(\(x), \(y), \(z), \(w))" }
}

extension Quaternion {
    convenience init(simd: simd_quatf) {
        self.init()
        stored = simd
    }

    convenience init(live: Live<simd_quatf>) {
        self.init()
        self.live = live
    }

    var simd: simd_quatf {
        get { live?.get() ?? stored }
        set {
            if let live { live.set(newValue) } else { stored = newValue }
        }
    }
}
