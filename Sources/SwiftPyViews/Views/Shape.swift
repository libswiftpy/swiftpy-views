//
//  Shape.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A shape through points, filled or outlined: a drawing canvas's stroke
/// turned into one, say.
///
/// ```python
/// from views import *
///
/// triangle = Shape([(20, 120), (100, 20), (180, 120)], fill=None, stroke=Color.TEAL, trim_to=0)
/// animate(lambda: setattr(triangle, "trim_to", 1))  # draws itself in
/// ```
///
/// Its points are measured from the top left of the space it's given, as a
/// canvas's are, so shapes stacked on a canvas in a `ZStack` sit where they
/// were drawn. With no height set, it's as tall as it is wide.
@Scriptable(base: .View)
@MainActor
@Observable
final class Shape {
    /// The points it runs through, as `(x, y)` tuples.
    var points: ShapePoints

    /// What fills it: a `Color`, or a hex string such as `#RRGGBB`; None for no fill.
    var fill: ColorValue?

    /// What outlines it: a `Color`, or a hex string; None for no outline.
    var stroke: ColorValue?

    /// The outline's width.
    var lineWidth: Double

    /// Whether its last point joins its first.
    var closed: Bool

    /// Where along its path it starts, from 0 to 1; changed in `animate`, it moves.
    var trimFrom: Double

    /// Where along its path it ends, from 0 to 1; changed in `animate`, it moves.
    var trimTo: Double

    /// Creates a shape.
    ///
    /// points: `(x, y)` tuples, or anything whose first two items are x and y, such as a drawing's `Point`s.
    /// fill: What fills it: a `Color`, such as `Color.TEAL`, or "#RRGGBB". Defaults to the foreground color; None for no fill.
    /// stroke: What outlines it. Defaults to None, no outline.
    /// line_width: The outline's width. Defaults to 1.
    /// closed: Whether its last point joins its first. Defaults to True.
    /// trim_from: Where along its path it starts, from 0 to 1. Defaults to 0.
    /// trim_to: Where along its path it ends, from 0 to 1. Defaults to 1, the whole path.
    init(
        points: ShapePoints,
        fill: ColorValue? = "primary",
        stroke: ColorValue? = nil,
        lineWidth: Double = 1,
        closed: Bool = true,
        trimFrom: Double = 0,
        trimTo: Double = 1
    ) throws {
        for color in [fill, stroke].compactMap(\.self) {
            _ = try SwiftUI.Color(pythonName: color.name)
        }
        self.points = points
        self.fill = fill
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.closed = closed
        self.trimFrom = trimFrom
        self.trimTo = trimTo
    }

    func body() -> AnyView {
        AnyView(ShapeContent(model: self))
    }
}

/// `views.ShapePoints`: points as `(x, y)` tuples, or anything whose first two
/// items are x and y. Read back from Python, they're `(x, y)` tuples.
struct ShapePoints: PythonConvertible {
    var points: [CGPoint]

    static var pyType: PyType { .object }

    static func fromPython(_ reference: PyRef) -> ShapePoints {
        let items = [PyObject].fromPython(reference)
        return ShapePoints(points: items.compactMap { item in
            let numbers = [Double].fromPython(item.reference)
            return numbers.count >= 2 ? CGPoint(x: numbers[0], y: numbers[1]) : nil
        })
    }

    func toPython() throws(PythonError) -> PyObject {
        let tuples = try points.map { point throws(PythonError) in
            try PyTuple(values: [Double(point.x).toPython(), Double(point.y).toPython()]).toPython()
        }
        return try tuples.toPython()
    }
}

private struct ShapeContent: View {
    let model: Shape

    var body: some View {
        // A trimmed shape animates its ends.
        let path = PointsPath(points: model.points.points, closed: model.closed)
            .trim(from: clamped(model.trimFrom), to: clamped(model.trimTo))
        SquareWhenUnbounded {
            SwiftUI.ZStack(alignment: .topLeading) {
                if let fill = color(model.fill) {
                    path.fill(fill)
                }
                if let stroke = color(model.stroke) {
                    path.stroke(stroke, style: StrokeStyle(lineWidth: model.lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .fillsAvailableSpace()
    }

    private func clamped(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }

    private func color(_ value: ColorValue?) -> SwiftUI.Color? {
        value.flatMap { try? SwiftUI.Color(pythonName: $0.name) }
    }
}

/// The points as they are, from the top left of the space it's given.
private struct PointsPath: SwiftUI.Shape {
    let points: [CGPoint]
    let closed: Bool

    func path(in rect: CGRect) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        path.addLines(points)
        if closed { path.closeSubpath() }
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
