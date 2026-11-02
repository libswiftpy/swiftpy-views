//
//  Stroke.swift
//  swiftpy-views
//

import PencilKit
import SwiftPy
import SwiftPyViews
import SwiftUI

// Python's types for what Swift hands over as plain objects, named as the
// interface writes them: `drawing.Point`, `drawing.PointValue` and so on.
typealias Point = PyObject
typealias PointValue = PyObject
typealias Bounds = PyTuple

/// A stroke drawn on a canvas, or made to put on one.
///
/// ```python
/// import drawing
///
/// line = drawing.Stroke([(10, 10), (120, 60)], tool=drawing.Tool.MARKER, width=12)
/// line.length  # 111.8…
/// ```
@Scriptable
@MainActor
final class Stroke: WrappedObject<PKStroke> {
    /// What it was drawn with; never `Tool.ERASER`.
    var tool: ToolValue { ToolValue(inkType: value.ink.inkType) }

    /// Its ink's color, as `#RRGGBBAA`.
    var color: String { value.ink.color.hexString }

    /// The points it was drawn through, as `Point`s.
    var points: [Point] {
        value.path.compactMap { try? Self.point($0, transform: value.transform) }
    }

    /// The box around what it draws: `(x, y, width, height)`.
    var bounds: Bounds {
        let rect = value.renderBounds
        return PyTuple(values: [rect.minX, rect.minY, rect.width, rect.height].compactMap { try? Double($0).toPython() })
    }

    /// How long it is along its path, in points.
    var length: Double { Double(pathLength) }

    /// Creates a stroke.
    ///
    /// points: `Point`s, or `(x, y)` tuples, in points from the canvas's top left.
    /// tool: What it's drawn with: a `Tool`, or its name, but not `Tool.ERASER`.
    /// color: A `views.Color`, or `#RRGGBB` or `#RRGGBBAA`.
    /// width: The ink's width, where a point doesn't give its own `size`.
    init(points: [PointValue], tool: ToolValue = "pen", color: ColorValue = "black", width: Double = 4) throws {
        guard let inkType = tool.inkType else {
            throw PythonError.ValueError(tool.isEraser
                ? "a stroke can't be drawn by the eraser"
                : "unknown tool: \(tool.name)")
        }
        let ink = PKInk(inkType, color: try PlatformColor(pythonName: color.name))
        let date = Date()
        let strokePoints = try points.map { try Self.strokePoint($0, width: width) }
        super.init(PKStroke(ink: ink, path: PKStrokePath(controlPoints: strokePoints, creationDate: date)))
    }

    internal override init(_ value: PKStroke) {
        super.init(value)
    }

    /// Points along it, for checking a shape or recognizing one: either
    /// `count` of them, evenly spaced from its start to its end, or one every
    /// `spacing` points.
    ///
    /// count: How many points, the first at the start and the last at the end.
    /// spacing: The distance between points along the path.
    func sample(count: Int? = nil, spacing: Double? = nil) throws -> [Point] {
        let path = value.path
        guard let first = path.first else { return [] }
        let length = pathLength

        let distances: [CGFloat]
        switch (count, spacing) {
        case let (count?, nil):
            guard count > 0 else { throw PythonError.ValueError("count must be positive") }
            distances = count == 1 ? [0] : (0..<count).map { length * CGFloat($0) / CGFloat(count - 1) }
        case let (nil, spacing?):
            guard spacing > 0 else { throw PythonError.ValueError("spacing must be positive") }
            distances = stride(from: 0, through: length, by: CGFloat(spacing)).map { $0 }
        default:
            throw PythonError.TypeError("give either count or spacing")
        }

        let end = CGFloat(path.count - 1)
        return try distances.map { distance in
            guard path.count > 1 else {
                return try Self.point(first, transform: value.transform)
            }
            // The last one at the very end, whatever rounding the distances had.
            let parameter = distance >= length
                ? end
                : min(path.parametricValue(0, offsetBy: .distance(distance)), end)
            return try Self.point(path.interpolatedPoint(at: parameter), transform: value.transform)
        }
    }

    /// Measured along points close enough together that the curve between
    /// them is all but straight.
    private var pathLength: CGFloat {
        let path = value.path
        guard path.count > 1, let last = path.last else { return 0 }
        var total: CGFloat = 0
        var previous: CGPoint?
        for point in path.interpolatedPoints(by: .distance(0.5)) {
            if let previous { total += previous.distance(to: point.location) }
            previous = point.location
        }
        if let previous { total += previous.distance(to: last.location) }
        return total
    }

    private static func point(_ point: PKStrokePoint, transform: CGAffineTransform) throws -> Point {
        guard let type = py.module("drawing")?.Point else {
            throw PythonError.ImportError("drawing.Point is not defined")
        }
        let location = point.location.applying(transform)
        return try type(
            Double(location.x), Double(location.y), Double(point.timeOffset), Double(point.force),
            Double(point.size.width), Double(point.opacity), Double(point.azimuth), Double(point.altitude)
        )
    }

    /// A `Point` or an `(x, y)` tuple: a `Point` is a tuple too, with the rest.
    private static func strokePoint(_ value: PointValue, width: Double) throws -> PKStrokePoint {
        let numbers = [Double].fromPython(value.reference)
        guard numbers.count >= 2 else {
            throw PythonError.TypeError("a point is a Point or an (x, y) tuple")
        }
        func number(_ index: Int, _ fallback: Double) -> CGFloat {
            CGFloat(index < numbers.count ? numbers[index] : fallback)
        }
        let size = number(4, width)
        return PKStrokePoint(
            location: CGPoint(x: numbers[0], y: numbers[1]),
            timeOffset: TimeInterval(number(2, 0)),
            size: CGSize(width: size, height: size),
            opacity: number(5, 1),
            force: number(3, 1),
            azimuth: number(6, 0),
            altitude: number(7, .pi / 2)
        )
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }
}

// MARK: - Tools

/// `drawing.ToolValue`: a `Tool`, or its name. Read back from Python, it's
/// the `Tool`.
struct ToolValue: StrEnumValue {
    static let enumName = "Tool"
    static let moduleName = "drawing"
    var name: String

    init(stringLiteral name: String) {
        self.name = name
    }

    init(inkType: PKInk.InkType) {
        let name = switch inkType {
        case .pencil: "pencil"
        case .marker: "marker"
        case .monoline: "monoline"
        case .fountainPen: "fountain_pen"
        case .watercolor: "watercolor"
        case .crayon: "crayon"
        default: "pen"
        }
        self.init(stringLiteral: name)
    }

    var isEraser: Bool { name == "eraser" }

    var inkType: PKInk.InkType? {
        switch name {
        case "pen": .pen
        case "pencil": .pencil
        case "marker": .marker
        case "monoline": .monoline
        case "fountain_pen": .fountainPen
        case "watercolor": .watercolor
        case "crayon": .crayon
        default: nil
        }
    }

    var isKnown: Bool { isEraser || inkType != nil }
}

// A member is a str too: a name converts, as it does for `views`' values.
@MainActor extension ToolValue: PythonConvertible {
    static func isConvertible(_ reference: PyRef) -> Bool { String.isConvertible(reference) }
}

// MARK: - Colors

#if canImport(UIKit)
typealias PlatformColor = UIColor
#else
typealias PlatformColor = NSColor
#endif

extension PlatformColor {
    convenience init(pythonName name: String) throws {
        self.init(try SwiftUI.Color(pythonName: name))
    }

    /// `#RRGGBBAA`, in sRGB, as it shows in light mode.
    var hexString: String {
        #if canImport(UIKit)
        let color = resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        let color = usingColorSpace(.sRGB) ?? self
        let red = color.redComponent, green = color.greenComponent
        let blue = color.blueComponent, alpha = color.alphaComponent
        #endif
        let channels = [red, green, blue, alpha].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }
}
