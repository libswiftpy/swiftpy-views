//
//  StrEnumValue.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// `views.AxisValue`: an `Axis`, or its name.
struct AxisValue: StrEnumValue {
    static let enumName = "Axis"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }
}

/// `views.PickerStyleValue`: a `PickerStyle`, or its name.
struct PickerStyleValue: StrEnumValue {
    static let enumName = "PickerStyle"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }
}

/// `views.ButtonRoleValue`: a `ButtonRole`, or its name.
struct ButtonRoleValue: StrEnumValue {
    static let enumName = "ButtonRole"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }
}

/// `views.ColorValue`: a `Color`, or a hex string such as "#RRGGBB". Read
/// back from Python, a hex string stays one.
public struct ColorValue: StrEnumValue {
    public static let enumName = "Color"
    public var name: String

    public init(stringLiteral name: String) {
        self.name = name
    }
}

/// A member of one of a module's StrEnums, or its name. Read back from
/// Python, it's the member.
public protocol StrEnumValue: Equatable, ExpressibleByStringLiteral where StringLiteralType == String {
    /// The enum's name in its module, such as "Alignment".
    static var enumName: String { get }
    /// The module that defines it; `views` by default.
    static var moduleName: String { get }
    var name: String { get }
}

// Main-actor isolated, apart from the literal, which a default needs. A
// member is a str too: a name converts, which the default's check, by the
// enum type, would refuse; declared on each, where it outranks that default.
@MainActor extension AxisValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool { String.isConvertible(reference) }
}

@MainActor extension PickerStyleValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool { String.isConvertible(reference) }
}

@MainActor extension ButtonRoleValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool { String.isConvertible(reference) }
}

@MainActor extension ColorValue: PythonConvertible {
    public static func isConvertible(_ reference: PyRef) -> Bool { String.isConvertible(reference) }
}

public extension StrEnumValue {
    static var moduleName: String { "views" }
}

@MainActor
public extension StrEnumValue {
    private static var enumType: PyObject? {
        py.module(moduleName)?[dynamicMember: enumName]
    }

    static var pyType: PyType {
        enumType.flatMap { PyType($0) } ?? .str
    }

    static func fromPython(_ reference: PyRef) -> Self {
        Self(stringLiteral: String.fromPython(reference))
    }

    func toPython() throws(PythonError) -> PyObject {
        if let member = try? Self.enumType?(name) { return member }
        return try name.toPython()
    }
}
