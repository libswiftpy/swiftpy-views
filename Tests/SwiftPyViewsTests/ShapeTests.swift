//
//  ShapeTests.swift
//  swiftpy-views
//

import CoreGraphics
import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct ShapeTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("""
        import views

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    @Test func runsThroughItsPoints() async throws {
        await Interpreter.run("_triangle = views.Shape([(20, 120), [100, 20], (180, 120, 0.5)], fill=views.Color.TEAL)")
        let triangle: Shape = try #require(py.main._triangle)
        #expect(triangle.points.points == [CGPoint(x: 20, y: 120), CGPoint(x: 100, y: 20), CGPoint(x: 180, y: 120)])
        #expect(triangle.closed)
        #expect(Interpreter.evaluate("_triangle.points[1] == (100.0, 20.0)") == true)
        #expect(Interpreter.evaluate("_triangle.fill == views.Color.TEAL") == true)
        #expect(Interpreter.evaluate("type(_triangle).__module__") == "views")

        await Interpreter.run("_triangle.points = [(0, 0), (10, 10)]\n_triangle.fill = None")
        #expect(triangle.points.points.count == 2)
        #expect(triangle.fill == nil)
    }

    @Test func trimsAndAnimatesItsEnds() async throws {
        await Interpreter.run("""
        _line = views.Shape([(0, 0), (100, 0)], fill=None, stroke=views.Color.RED, trim_from=0.1, trim_to=0.8)
        views.animate(lambda: setattr(_line, "trim_to", 1))
        """)
        let line: Shape = try #require(py.main._line)
        #expect(line.trimFrom == 0.1)
        #expect(line.trimTo == 1)
        #expect(Interpreter.evaluate("views.Shape([(0, 0)]).trim_to") == 1.0)
    }

    @Test func refusesAnUnknownColor() async {
        #expect(Interpreter.evaluate("_raised(lambda: views.Shape([(0, 0)], fill='plaid'))") == "ValueError")
        #expect(Interpreter.evaluate("_raised(lambda: views.Shape([(0, 0)], stroke='#12'))") == "ValueError")
    }

    @Test func isAViewToStack() async {
        await Interpreter.run("_shape_stack = views.ZStack(views.Shape([(0, 0), (5, 5)], stroke='#FF0000', line_width=3).padding())")
        #expect(Interpreter.evaluate("isinstance(_shape_stack, views.View)") == true)
    }
}
