//
//  SliderTests.swift
//  swiftpy-views
//

import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct SliderTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("import views")
    }

    @Test func pythonBuildsASliderAndHearsOnlyTheUsersChanges() async throws {
        await Interpreter.run("""
        _changes = []
        _slider = views.Slider(value=3, steps=10, label="Level",
                               on_change=lambda value: _changes.append(value))
        """)
        let slider: Slider = try #require(py.main._slider)
        #expect(slider.value == 3)
        #expect(slider.bounds == 0...10)
        #expect(slider.steps == 10)
        #expect(slider.label == "Level")
        #expect(Interpreter.evaluate("type(_slider).__module__") == "views")

        slider.userChange(to: 4)
        await Interpreter.run("_slider.value = 7")
        #expect(slider.value == 7)
        #expect(Interpreter.evaluate("_changes") == [4.0])
    }

    @Test func ticksMarkEachStop() {
        #expect(Slider(steps: 10).tickValues == Array(0...10).map(Double.init))
        #expect(Slider().tickValues.isEmpty)
        #expect(Slider().bounds == 0...1)
        #expect(Slider(steps: 100).tickValues.isEmpty)
    }
}
