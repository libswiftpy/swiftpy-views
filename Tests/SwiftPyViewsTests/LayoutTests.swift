//
//  LayoutTests.swift
//  swiftpy-views
//

import Foundation
import ImageIO
import SwiftUI
import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct LayoutTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("from views import *")
    }

    private func evaluate<T: PythonConvertible>(_ expression: String) -> T? {
        Interpreter.evaluate(expression)
    }

    @Test func lengthsAddPoints() async {
        await Interpreter.run("""
        _less = Percent(50) - 10
        _more = 10 + Percent(5)
        _rest = 100 - Percent(25)
        _refused = []
        for _make in (lambda: Percent(30) + Percent(20), lambda: Percent(5) * 2, lambda: Percent(5) + "a"):
            try:
                _make()
            except TypeError:
                _refused.append(True)
        """)
        #expect(evaluate("repr(_less)") == "Percent(50) - 10")
        #expect(evaluate("repr(_more)") == "Percent(5) + 10")
        #expect(evaluate("repr(_rest)") == "Percent(-25) + 100")
        #expect(evaluate("_less == LengthExpression(50, -10)") == true)
        #expect(evaluate("len(_refused)") == 3)
    }

    @Test func wrappersKeepWhatTheyreGiven() async {
        await Interpreter.run("""
        _text = Text("a")
        _sized = _text.size(width=Percent(50), max_height=40)
        _moved = _text.transform(x=Percent(10) - 5)
        _sized.width = 120
        _moved.y = 3
        _container = SizeContainer(_sized, alignment=Alignment.TOP_LEADING)
        _made = [Sizing(_text, width=10).width, Transform(_text, x=1).x, Transform(_text).y]
        """)
        #expect(evaluate("type(_sized).__name__") == "Sizing")
        #expect(evaluate("_sized.content is _text and _moved.content is _text") == true)
        #expect(evaluate("repr([_sized.width, _sized.height, _sized.max_height])") == "[120.0, None, 40.0]")
        #expect(evaluate("repr([_moved.x, _moved.y])") == "[Percent(10) - 5, 3.0]")
        #expect(evaluate("_text.size() is not _text.size()") == true)
        #expect(evaluate("_container.alignment") == "top-leading")
        #expect(evaluate("repr(_made)") == "[10.0, 1.0, 0.0]")
    }

    @Test func alignmentReadsBackAsTheEnum() async {
        await Interpreter.run("""
        _named = VStack("a", alignment="leading")
        _layered = ZStack("a")
        _layered.alignment = Alignment.BOTTOM_TRAILING
        _read = [_named.alignment, _layered.alignment, HStack("a").alignment, SizeContainer("a").alignment]
        """)
        #expect(evaluate("_read == [Alignment.LEADING, Alignment.BOTTOM_TRAILING, Alignment.CENTER, Alignment.CENTER]") == true)
        #expect(evaluate("all(type(a) is Alignment for a in _read)") == true)
    }

    /// The image's colour at a point, by name.
    private func sampler(_ image: PlatformImage, width: CGFloat) throws -> (CGFloat, CGFloat) -> String {
        let data = try #require(image.png)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let scale = CGFloat(cgImage.width) / width
        return { x, y in
            var pixel: [UInt8] = [0, 0, 0, 0]
            let context = CGContext(
                data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(cgImage, in: CGRect(
                x: -x * scale, y: y * scale - CGFloat(cgImage.height) + 1,
                width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)
            ))
            return pixel[0] > 200 && pixel[2] < 60 ? "red" : pixel[2] > 200 && pixel[0] < 60 ? "blue" : "\(pixel)"
        }
    }

    /// `_view`, 200 points wide on blue, as a function of a point.
    private func render(_ setup: String) async throws -> (CGFloat, CGFloat) -> String {
        await Interpreter.run("""
        _red = Rectangle("#FF0000", 0)
        \(setup)
        """)
        let view = try #require((py.main._view as PyObject?)?.asView)
        let image = await ViewSnapshot.image(of: view, width: 200, delay: 0, background: .blue)
        return try sampler(image, width: 200)
    }

    @Test func sizesByPercent() async throws {
        let half = try await render("""
        _view = SizeContainer(_red.size(width=Percent(50), height=Percent(100)), alignment="leading").size(width=200, height=100)
        """)
        #expect(half(50, 50) == "red")
        #expect(half(150, 50) == "blue")

        // No container: the percentage is left to the view, which fills.
        let unresolved = try await render("_view = _red.size(width=Percent(50), height=20)")
        #expect(unresolved(150, 10) == "red")
    }

    @Test func keepsAnAspectRatio() async throws {
        // 30% wide and square: 60 by 60 in the corner.
        let square = try await render("""
        _view = SizeContainer(_red.size(width=Percent(30), aspect_ratio=1), alignment="top-leading").size(width=200, height=200)
        """)
        #expect(square(30, 30) == "red")
        #expect(square(30, 90) == "blue")
        #expect(square(90, 30) == "blue")

        // No side given: as large as fits, twice as wide as tall.
        let wide = try await render("""
        _view = SizeContainer(_red.size(aspect_ratio=2), alignment="top").size(width=200, height=200)
        """)
        #expect(wide(100, 50) == "red")
        #expect(wide(100, 150) == "blue")
    }

    @Test func offsetsByPercent() async throws {
        let moved = try await render("""
        _piece = _red.size(width=Percent(50), height=Percent(100)).transform()
        _piece.x = Percent(50)
        _view = SizeContainer(_piece, alignment="leading").size(width=200, height=100)
        """)
        #expect(moved(50, 50) == "blue")
        #expect(moved(150, 50) == "red")

        let short = try await render("""
        _view = SizeContainer(
            _red.size(width=Percent(50), height=Percent(100)).transform(x=Percent(50) - 20),
            alignment="leading",
        ).size(width=200, height=100)
        """)
        #expect(short(75, 50) == "blue")
        #expect(short(85, 50) == "red")
        #expect(short(185, 50) == "blue")
    }

    @Test func aScrollViewIsAReference() async throws {
        let half = try await render("""
        _view = ScrollView(_red.size(width=Percent(50), height=Percent(100))).size(width=200, height=150)
        """)
        #expect(half(50, 140) == "red")
        #expect(half(150, 75) == "blue")
    }

    // Offered no height, as in a card, it takes its content's: a percentage of
    // it there would grow without end, so the content keeps its own height.
    @Test func aScrollViewOfferedNoHeightLeavesItToTheContent() async throws {
        await Interpreter.run("""
        _grower = ScrollView(Rectangle("#FF0000", 0).size(width=Percent(100), height=Percent(110) + 10))
        """)
        let grower = try #require((py.main._grower as PyObject?)?.asView)
        let image = await ViewSnapshot.image(of: AnyView(SwiftUI.ScrollView { grower }), width: 200, delay: 0.1, background: .blue)
        let at = try sampler(image, width: 200)
        #expect(at(100, 5) == "red", "the width still resolves")
        #expect(image.size.height < 400, "\(image.size)")
    }

    // A red bar along the container's bottom edge shows how tall it came out.
    private let barAtBottom = """
    _container = SizeContainer(_red.size(width=Percent(100), height=10), alignment="bottom")
    """

    @Test func inACardItsSquare() async throws {
        await Interpreter.run("_red = Rectangle('#FF0000', 0)\n" + barAtBottom)
        let container = try #require((py.main._container as PyObject?)?.asView)
        let view = AnyView(
            SwiftUI.ScrollView { container }
                .environment(\.sizeContainerUnboundedAxis, .aspectRatio(1))
                .frame(height: 300)
        )
        let image = await ViewSnapshot.image(of: view, width: 200, delay: 0.1, background: .blue)
        let at = try sampler(image, width: 200)
        #expect(at(100, 195) == "red")
        #expect(at(100, 250) == "blue")
    }

    @Test func inAScrollViewItTakesTheVisibleLength() async throws {
        let at = try await render(barAtBottom + "\n" + """
        _view = ScrollView(_container).size(height=150)
        """)
        #expect(at(100, 145) == "red")
        #expect(at(100, 100) == "blue")
    }
}
