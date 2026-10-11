//
//  ControlsTests.swift
//  swiftpy-views
//

import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct ControlsTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("from views import *\n_changes = []")
    }

    @Test func textFieldHearsTheUserAndSubmits() async throws {
        await Interpreter.run("""
        _changes.clear()
        _field = TextField("Name", "Ada", secure=True,
                           on_change=_changes.append,
                           on_submit=lambda: _changes.append("submitted"))
        """)
        let field: SwiftPyViews.TextField = try #require(py.main._field)
        #expect(field.prompt == "Name")
        #expect(field.secure)

        field.userChange(to: "Ada L")
        field.userChange(to: "Ada L")
        field.submit()
        await Interpreter.run("_field.text = 'from code'")
        #expect(field.text == "from code")
        #expect(Interpreter.evaluate("_changes") == ["Ada L", "submitted"])
    }

    @Test func toggleHearsOnlyTheUser() async throws {
        await Interpreter.run("""
        _changes.clear()
        _toggle = Toggle("Wi-Fi", on_change=_changes.append)
        _toggle.is_on = True
        """)
        let toggle: SwiftPyViews.Toggle = try #require(py.main._toggle)
        #expect(toggle.isOn)
        toggle.userChange(to: false)
        #expect(Interpreter.evaluate("_changes") == [false])
        #expect(Interpreter.evaluate("_toggle.is_on") == false)
    }

    @Test func stepperStopsAtItsLimits() async throws {
        await Interpreter.run("""
        _changes.clear()
        _stepper = Stepper("Count", 8, minimum=0, maximum=10, step=3, on_change=_changes.append)
        """)
        let stepper: SwiftPyViews.Stepper = try #require(py.main._stepper)
        stepper.userStep(up: true)
        #expect(stepper.value == 10)
        #expect(!stepper.canIncrement)
        stepper.userStep(up: true)
        stepper.userStep(up: false)
        #expect(Interpreter.evaluate("_changes") == [10, 7])

        let unbounded = Stepper(label: try #require(py.retain("n")), value: -5)
        unbounded.userStep(up: false)
        #expect(unbounded.value == -6)
        #expect(unbounded.canDecrement)
    }

    @Test func pickerReadsAListOrADictInOrder() async throws {
        await Interpreter.run("""
        _changes.clear()
        _list = Picker("Size", ["S", "M", "L"], "M", style="segmented")
        _dict = Picker("Color", {"r": "Red", "g": "Green", "b": "Blue"},
                       on_change=_changes.append)
        """)
        let list: SwiftPyViews.Picker = try #require(py.main._list)
        #expect(list.choices.map(\.value) == ["S", "M", "L"])
        #expect(list.choices.map(\.title) == ["S", "M", "L"])
        #expect(list.selection == "M")

        let dict: SwiftPyViews.Picker = try #require(py.main._dict)
        #expect(dict.choices.map(\.value) == ["r", "g", "b"])
        #expect(dict.choices.map(\.title) == ["Red", "Green", "Blue"])
        dict.userChange(to: "g")
        #expect(Interpreter.evaluate("_dict.selection") == "g")
        #expect(Interpreter.evaluate("_changes") == ["g"])
    }

    @Test func anAsyncCallbackRunsToItsEnd() async throws {
        await Interpreter.run("""
        import asyncio
        _done = []
        async def _slow():
            await asyncio.sleep(0.01)
            _done.append(True)
        """)
        let action: PyObject = try #require(py.main._slow)
        let task = try #require(action.callback())
        await task.value
        #expect(Interpreter.evaluate("_done") == [true])

        await Interpreter.run("_sync = lambda: 1")
        let sync: PyObject = try #require(py.main._sync)
        #expect(sync.callback() == nil)
    }

    @Test func progressAndDividerAreViews() async {
        await Interpreter.run("""
        _progress = ProgressView(0.5, label="Loading")
        _spinner = ProgressView()
        """)
        #expect(Interpreter.evaluate("_progress.value") == 0.5)
        #expect(Interpreter.evaluate("_spinner.value is None") == true)
        #expect(Interpreter.evaluate("isinstance(Divider(), View)") == true)
    }
}
