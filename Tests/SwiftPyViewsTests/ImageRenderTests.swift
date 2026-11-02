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

    // The alpha of the top-left pixel, where a short text draws nothing.
    private func cornerAlpha(_ name: String) throws -> UInt8 {
        let data: Data = try #require(py.main[dynamicMember: name])
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
        return pixel[3]
    }

    @Test func fillsItsBackground() async throws {
        await Interpreter.run("""
        _opaque = (await Image.render(Text("Hi").padding(), width=200)).png()
        _clear = (await Image.render(Text("Hi").padding(), width=200, background=Color.CLEAR)).png()
        _red = (await Image.render(Text("Hi").padding(), width=200, background="#FF0000")).png()
        _bad = None
        try:
            await Image.render(Text("Hi"), background="nope")
        except Exception as e:
            _bad = type(e).__name__
        """)
        #expect(try cornerAlpha("_opaque") == 255)
        #expect(try cornerAlpha("_clear") == 0)
        #expect(try cornerAlpha("_red") == 255)
        #expect(Interpreter.evaluate("_bad") == "ValueError")
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

    @Test func aFittedSymbolFillsItsWidth() async throws {
        await Interpreter.run("""
        _fitted = (await Image.render(Image.system("square.fill", fit=True), width=200)).png()
        _plain = (await Image.render(Image.system("square.fill"), width=200)).png()
        _flags = (Image.system("star", fit=True).scale_to_fit, Image.system("star").scale_to_fit)
        """)
        #expect(try pixelSize("_fitted").height > 4 * pixelSize("_plain").height)
        #expect(Interpreter.evaluate("str(_flags)") == "(True, False)")
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
