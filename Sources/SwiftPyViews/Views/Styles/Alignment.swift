//
//  Alignment.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

// The names `views.Alignment` gives, as SwiftUI's alignments.
enum Alignment {
    internal static func horizontal(_ alignment: String) -> HorizontalAlignment? {
        switch alignment {
        case "left", "leading", "top-leading", "bottom-leading": .leading
        case "right", "trailing", "top-trailing", "bottom-trailing": .trailing
        default: nil
        }
    }
    
    internal static func vertical(_ alignment: String) -> VerticalAlignment? {
        switch alignment {
        case "top", "top-leading", "top-trailing": .top
        case "bottom", "bottom-leading", "bottom-trailing": .bottom
        default: nil
        }
    }

    internal static func both(_ alignment: String) -> SwiftUI.Alignment {
        SwiftUI.Alignment(
            horizontal: horizontal(alignment) ?? .center,
            vertical: vertical(alignment) ?? .center
        )
    }
}

/// `views.AlignmentValue`: an `Alignment`, or its name. Read back from Python,
/// it's the `Alignment`.
struct AlignmentValue: Equatable, ExpressibleByStringLiteral {
    var name: String

    // A literal, so a default reads `= 'center'` in Python too.
    init(stringLiteral name: String) {
        self.name = name
    }
}

@MainActor
extension AlignmentValue: PythonConvertible {
    private static var enumType: PyObject? {
        py.module("views")?.Alignment
    }

    static var pyType: PyType {
        enumType.flatMap { PyType($0) } ?? .str
    }

    // An `Alignment` is a str too.
    static func isConvertible(_ reference: PyRef) -> Bool {
        String.isConvertible(reference)
    }

    static func fromPython(_ reference: PyRef) -> AlignmentValue {
        AlignmentValue(stringLiteral: String.fromPython(reference))
    }

    func toPython() throws(PythonError) -> PyObject {
        if let member = try? Self.enumType?(name) { return member }
        return try name.toPython()
    }
}
