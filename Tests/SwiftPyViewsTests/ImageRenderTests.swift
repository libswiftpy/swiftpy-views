//
//  ImageRenderTests.swift
//  swiftpy-views
//

import Foundation
import ImageIO
import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct ImageRenderTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("""
        from views import *

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    private func pixelSize(_ name: String) throws -> (width: Int, height: Int) {
        let data: Data = try #require(py.main[dynamicMember: name])
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    @Test func drawsAViewAtItsWidth() async throws {
        await Interpreter.run("""
        _png = (await Image.render(VStack(Text("Hi"), Text("there")), width=200)).png()
        _one = (await Image.render(Text("Hi"), width=200)).png()
        """)
        let size = try pixelSize("_png")
        let one = try pixelSize("_one")
        #expect(size.width > 0 && size.width % 200 == 0)
        // The height fits the content: two lines are taller than one.
        #expect(size.height > one.height)
        #expect(one.height > 0)
    }

    @Test func drawsAStringAsText() async throws {
        await Interpreter.run("_text = (await Image.render('hello', width=100)).png()")
        #expect(try pixelSize("_text").width > 0)
    }

    @Test func pngRoundTrips() async throws {
        await Interpreter.run("""
        _again = Image((await Image.render('hello', width=100)).png()).png()
        """)
        #expect(try pixelSize("_again").width > 0)
    }

    @Test func refusesWhatItCantDraw() async {
        await Interpreter.run("""
        _symbol = _raised(lambda: Image.system("star").png())
        try:
            await Image.render(42)
            _render = None
        except Exception as e:
            _render = type(e).__name__
        """)
        #expect(Interpreter.evaluate("_symbol") == "ValueError")
        #expect(Interpreter.evaluate("_render") == "TypeError")
    }
}
