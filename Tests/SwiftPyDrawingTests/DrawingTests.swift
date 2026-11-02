//
//  DrawingTests.swift
//  swiftpy-views
//

import PencilKit
import Testing
import SwiftPy
import SwiftPyViews
@testable import SwiftPyDrawing

@MainActor
@Suite(.serialized)
struct DrawingTests {
    init() async {
        SwiftPyViews.initialize()
        SwiftPyDrawing.initialize()
        await Interpreter.run("""
        import views, drawing

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    @Test func aStrokeMadeInPythonReadsBack() async throws {
        await Interpreter.run("""
        _stroke = drawing.Stroke([(10, 20), drawing.Point(110, 20, force=0.5)], tool=drawing.Tool.MARKER, color="#FF0000", width=6)
        """)
        #expect(Interpreter.evaluate("_stroke.tool == drawing.Tool.MARKER") == true)
        #expect(Interpreter.evaluate("_stroke.color") == "#FF0000FF")
        #expect(Interpreter.evaluate("[[p.x, p.y] for p in _stroke.points]") == [[10.0, 20.0], [110.0, 20.0]])
        #expect(Interpreter.evaluate("_stroke.points[0].size") == 6.0)
        #expect(Interpreter.evaluate("_stroke.points[1].force") == 0.5)
        #expect(Interpreter.evaluate("len(_stroke.bounds)") == 4)
        #expect(Interpreter.evaluate("type(_stroke).__module__") == "drawing")
    }

    @Test func theEraserDrawsNoStroke() async {
        #expect(Interpreter.evaluate("_raised(lambda: drawing.Stroke([(0, 0), (1, 1)], tool=drawing.Tool.ERASER))") == "ValueError")
        #expect(Interpreter.evaluate("_raised(lambda: drawing.Stroke([(0, 0), (1, 1)], tool='brush'))") == "ValueError")
        #expect(Interpreter.evaluate("_raised(lambda: drawing.Stroke([(0,)]))") == "TypeError")
    }

    @Test func samplesAStrokeEvenly() async throws {
        await Interpreter.run("_line = drawing.Stroke([(0, 0), (100, 0)])")
        let length: Double = try #require(Interpreter.evaluate("_line.length"))
        #expect(abs(length - 100) < 1)

        #expect(Interpreter.evaluate("len(_line.sample(count=10))") == 10)
        let ends: [Double] = try #require(Interpreter.evaluate("[_line.sample(count=10)[0].x, _line.sample(count=10)[-1].x]"))
        #expect(abs(ends[0]) < 0.5 && abs(ends[1] - 100) < 0.5)

        let spaced: [Double] = try #require(Interpreter.evaluate("[p.x for p in _line.sample(spacing=25)]"))
        #expect(spaced.count == 5)
        #expect(abs(spaced[1] - 25) < 1)

        #expect(Interpreter.evaluate("_raised(lambda: _line.sample())") == "TypeError")
        #expect(Interpreter.evaluate("_raised(lambda: _line.sample(count=0))") == "ValueError")
    }

    @Test func strokesFromCodeCanBeUndoneAndDontCallOnChange() async throws {
        await Interpreter.run("""
        _changes = []
        _canvas = drawing.Canvas(on_change=lambda strokes: _changes.append(len(strokes)))
        _canvas.strokes = [drawing.Stroke([(0, 0), (50, 50)]), drawing.Stroke([(0, 50), (50, 0)])]
        """)
        #expect(Interpreter.evaluate("len(_canvas.strokes)") == 2)

        await Interpreter.run("_canvas.clear()")
        #expect(Interpreter.evaluate("len(_canvas.strokes)") == 0)
        await Interpreter.run("_canvas.undo()")
        #expect(Interpreter.evaluate("len(_canvas.strokes)") == 2)
        await Interpreter.run("_canvas.undo()")
        #expect(Interpreter.evaluate("len(_canvas.strokes)") == 0)
        #expect(Interpreter.evaluate("_changes") == [Int]())

        // What the canvas view reports for the user.
        let canvas: Canvas = try #require(py.main._canvas)
        let stroke = try Stroke(points: [try point(1, 1), try point(9, 9)])
        canvas.userChange(to: PKDrawing(strokes: [stroke.value]))
        try await Task.sleep(for: .milliseconds(50))
        #expect(Interpreter.evaluate("_changes") == [1])
    }

    @Test func aStrokeCanBecomeAShapeAndLeaveTheCanvas() async throws {
        await Interpreter.run("""
        _shapes = views.Group()
        def _filled(strokes):
            for stroke in strokes:
                _shapes.append(views.Shape(stroke.points, fill=views.Color.TEAL))
            _shape_canvas.strokes = []
        _shape_canvas = drawing.Canvas(on_change=_filled)
        _scene = views.ZStack(_shapes, _shape_canvas)
        """)
        let canvas: Canvas = try #require(py.main._shape_canvas)
        let stroke = try Stroke(points: [try point(0, 0), try point(40, 0), try point(20, 30)])
        canvas.userChange(to: PKDrawing(strokes: [stroke.value]))

        #expect(Interpreter.evaluate("len(_shapes)") == 1)
        #expect(Interpreter.evaluate("_shapes[0].points[1] == (40.0, 0.0)") == true)
        #expect(canvas.strokes.isEmpty)
        // Undo brings the stroke back to the canvas.
        canvas.undo()
        #expect(canvas.strokes.count == 1)
    }

    @Test func choosesTheToolFromCode() async throws {
        await Interpreter.run("_canvas = drawing.Canvas(tool='pencil', color=views.Color.BLUE, width=3)")
        let canvas: Canvas = try #require(py.main._canvas)
        let pencil = try #require(canvas.pkTool as? PKInkingTool)
        #expect(pencil.inkType == .pencil)
        #expect(pencil.width == 3)

        await Interpreter.run("_canvas.tool = drawing.Tool.ERASER")
        #expect(canvas.pkTool is PKEraserTool)
        #expect(Interpreter.evaluate("_canvas.tool == drawing.Tool.ERASER") == true)
        #expect(Interpreter.evaluate("_raised(lambda: drawing.Canvas(tool='brush'))") == "ValueError")
    }

    @Test func drawsItsStrokesIntoAnImage() async throws {
        await Interpreter.run("""
        _canvas = drawing.Canvas()
        _canvas.strokes = [drawing.Stroke([(0, 0), (80, 40)], width=8)]
        _png = _canvas.image(background=views.Color.WHITE).png()
        """)
        let png: Data = try #require(py.main._png)
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(Interpreter.evaluate("_raised(lambda: drawing.Canvas().image())") == "ValueError")
    }

    @Test func isAViewToPutInOthers() async {
        await Interpreter.run("_stack = views.VStack(drawing.Canvas().padding(), 'Draw here')")
        #expect(Interpreter.evaluate("isinstance(_stack, views.View)") == true)
    }
}

@MainActor
private func point(_ x: Double, _ y: Double) throws -> PyObject {
    try PyTuple(values: [x.toPython(), y.toPython()]).toPython()
}
