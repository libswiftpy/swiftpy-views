//
//  Length.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A length in points, or a percentage of the nearest `SizeContainer` plus
/// points: `views.Length`, a number or a `views.LengthExpression`.
struct Length: Equatable {
    var percent: Double = 0
    var points: Double = 0

    /// Points, or nil when it needs a reference there isn't.
    func resolve(against reference: CGFloat?) -> CGFloat? {
        if percent == 0 { return points }
        guard let reference else { return nil }
        return reference * percent / 100 + points
    }
}

// So a default reads `= 0` in Python too.
extension Length: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    init(integerLiteral points: Int) {
        self.init(points: Double(points))
    }

    init(floatLiteral points: Double) {
        self.init(points: points)
    }
}

@MainActor
extension Length: PythonConvertible {
    // Looked up once `views` has defined it.
    private static var expressionType: PyObject? {
        py.module("views")?.LengthExpression
    }

    static var pyType: PyType {
        expressionType.flatMap { PyType($0) } ?? .float
    }

    static func isConvertible(_ reference: PyRef) -> Bool {
        Double.isConvertible(reference)
            || (expressionType.flatMap { PyType($0) }?.isInstance(reference) ?? false)
    }

    static func fromPython(_ reference: PyRef) -> Length {
        if Double.isConvertible(reference) {
            return Length(points: Double.fromPython(reference))
        }
        let expression = PyObject(retaining: reference)
        return Length(percent: expression.percent ?? 0, points: expression.points ?? 0)
    }

    func toPython() throws(PythonError) -> PyObject {
        if percent == 0 { return try points.toPython() }
        guard let type = Self.expressionType else {
            throw .ImportError("views.LengthExpression is not defined")
        }
        return try type(percent, points)
    }
}

/// The size of the nearest `SizeContainer`, which percentages are of: nil on
/// an axis it has no length for.
struct SizeReference: Equatable {
    var width: CGFloat?
    var height: CGFloat?
}

/// How a `SizeContainer` sizes an axis it's offered no length on, such as a
/// scroll view's.
public enum SizeContainerUnboundedAxis: Equatable, Sendable {
    /// The scroll view's visible length, or the other axis's where there's none.
    case visibleLength
    /// From the other axis: width over height, so 1 is square.
    case aspectRatio(CGFloat)
}

public extension EnvironmentValues {
    /// Set by the notebook to `.aspectRatio(1)`, so a container in a card is square.
    @Entry var sizeContainerUnboundedAxis: SizeContainerUnboundedAxis = .visibleLength
}

extension EnvironmentValues {
    @Entry var sizeReference = SizeReference()
}
