//
//  WidgetsTests.swift
//  swiftpy-views
//

import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct WidgetsTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("""
        from views import *
        from widgets import *

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    @Test func comesFromItsOwnModule() {
        #expect(Interpreter.evaluate("Widget.__module__") == "widgets")
        #expect(Interpreter.evaluate("WidgetSize.EXTRA_LARGE.value") == "extra_large")
    }

    @Test func takesAViewOrAFunction() async throws {
        await Interpreter.run("""
        _plain = Widget(Text("hi"))
        _built = Widget(lambda size: Text(size.value), sizes=[WidgetSize.SMALL, WidgetSize.MEDIUM], refresh=60)
        """)
        let plain: SwiftPyViews.Widget = try #require(py.main._plain)
        #expect(plain.names == [.small])
        #expect(plain.refresh == nil)
        #expect(plain.content.asView != nil)

        let built: SwiftPyViews.Widget = try #require(py.main._built)
        #expect(built.names == [.small, .medium])
        #expect(built.refresh == 60)
        #expect(built.content.asView == nil)
        #expect(Interpreter.evaluate("isinstance(_built, View)") == true)
    }

    @Test func buildsEachSizeWithItsWidgetSize() async throws {
        await Interpreter.run("""
        _sizes = []
        def _content(size: WidgetSize) -> View:
            _sizes.append(size)
            return Text(size.value)
        _widget = Widget(_content, sizes=[WidgetSize.SMALL, WidgetSize.LARGE])
        """)
        let widget: SwiftPyViews.Widget = try #require(py.main._widget)
        for size in widget.names {
            guard case .view = await widget.build(size) else {
                Issue.record("expected a view for \(size)")
                return
            }
        }
        #expect(Interpreter.evaluate("_sizes == [WidgetSize.SMALL, WidgetSize.LARGE]") == true)

        widget.reload()
        #expect(widget.reloads == 1)
    }

    @Test func aFailingFunctionShowsItsError() async throws {
        await Interpreter.run("""
        def _broken(size):
            raise ValueError("no data")
        _broken_widget = Widget(_broken)
        _wrong_widget = Widget(lambda size: 42)
        """)
        let broken: SwiftPyViews.Widget = try #require(py.main._broken_widget)
        guard case .failure(let message) = await broken.build(.small) else {
            Issue.record("expected a failure")
            return
        }
        #expect(message.contains("ValueError: no data"), "\(message)")
        #expect(!message.contains("\u{1B}["))

        let wrong: SwiftPyViews.Widget = try #require(py.main._wrong_widget)
        guard case .failure(let wrongMessage) = await wrong.build(.small) else {
            Issue.record("expected a failure")
            return
        }
        #expect(wrongMessage.contains("not a view"), "\(wrongMessage)")
    }

    @Test func rejectsUnknownSizes() {
        #expect(Interpreter.evaluate("_raised(lambda: Widget(Text('x'), sizes=['huge']))") == "ValueError")
        #expect(Interpreter.evaluate("_raised(lambda: Widget(Text('x'), sizes=[]))") == "ValueError")
    }
}
