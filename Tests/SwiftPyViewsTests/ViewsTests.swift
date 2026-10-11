//
//  ViewsTests.swift
//  swiftpy-views
//

import SwiftUI
import Testing
import SwiftPy
@testable import SwiftPyViews

@MainActor
@Suite(.serialized)
struct ViewsTests {
    init() async {
        SwiftPyViews.initialize()
        await Interpreter.run("from views import *")
    }

    @Test func containersTakeTheirViewsAndKeywords() async throws {
        await Interpreter.run("""
        _stack = VStack("a", Text("b"), alignment="leading", spacing=4)
        _row = HStack(Text("c"))
        _section = Section("d", title="Items")
        """)
        let stack: SwiftPyViews.VStack = try #require(py.main._stack)
        #expect(stack.content.objects.count == 2)
        #expect(stack.alignment == "leading")
        #expect(stack.spacing == 4)
        let row: SwiftPyViews.HStack = try #require(py.main._row)
        #expect(row.spacing == nil)
        let section: SwiftPyViews.Section = try #require(py.main._section)
        #expect(section.title == "Items")
        #expect(section.content.objects.count == 1)
        #expect(Interpreter.evaluate("type(_stack).__module__") == "views")
        #expect(Interpreter.evaluate("isinstance(Form(_section), View)") == true)
    }

    @Test func contentChangesLikeAList() async throws {
        await Interpreter.run("""
        _stack = VStack("a", "b")
        _content = _stack.content
        _content.append("c")
        _content.insert(0, "start")
        _content[1] = "A"
        del _content[-1]
        _content.remove("b")
        _items = [item for item in _content]
        try:
            _content[5]
            _out_of_range = False
        except IndexError:
            _out_of_range = True
        try:
            _content.remove("missing")
            _missing = False
        except ValueError:
            _missing = True
        """)
        #expect(Interpreter.evaluate("_items") == ["start", "A"])
        #expect(Interpreter.evaluate("len(_content)") == 2)
        #expect(Interpreter.evaluate("_out_of_range") == true)
        #expect(Interpreter.evaluate("_missing") == true)

        #expect(Interpreter.evaluate("isinstance(_content, Group)") == true)
        await Interpreter.run("_content.clear()")
        let stack: SwiftPyViews.VStack = try #require(py.main._stack)
        #expect(stack.content.objects.isEmpty)
    }

    @Test func aGroupIsTheListItHolds() async throws {
        await Interpreter.run("""
        _group = Group("a")
        _stack = VStack(_group, "b")
        _group.append("c")
        """)
        let group: SwiftPyViews.Group = try #require(py.main._group)
        #expect(group.objects.count == 2)
        #expect(Interpreter.evaluate("len(_stack.content)") == 2)
    }

    @Test func removingAViewKeepsTheOthersIdentity() async throws {
        await Interpreter.run("""
        _a, _b = Text("a"), Text("b")
        _stack = VStack(_a, _b, "same", "same")
        """)
        let stack: SwiftPyViews.VStack = try #require(py.main._stack)
        let before = stack.content.identified.map(\.id)
        #expect(Set(before).count == 4)

        await Interpreter.run("del _stack.content[0]")
        #expect(stack.content.identified.map(\.id) == Array(before.dropFirst()))
    }

    @Test func modifiersWrapTheViewTheyAreCalledOn() async throws {
        await Interpreter.run("""
        class _Card(View):
            def body(self):
                return Text("card")

        _text = Text("a")
        _modified = (_text.padding(8, "horizontal").font("headline", monospaced=True)
                     .bold().italic().foreground("#FF000080").background("blue")
                     .tint("accent").disabled().align("leading")
                     .on_appear(lambda: None).toolbar("Done"))
        _card = _Card().padding()
        """)
        let modified: ModifiedView = try #require(py.main._modified)
        let card: ModifiedView = try #require(py.main._card)
        #expect(Interpreter.evaluate("isinstance(_modified, View)") == true)
        _ = modified.body()
        _ = card.body()
    }

    @Test(arguments: [
        "Text('a').foreground('nope')",
        "Text('a').background('#12')",
        "Text('a').font('huge')",
        "Text('a').padding(edges='inside')",
    ])
    func unknownStyleNamesRaise(_ expression: String) async {
        await Interpreter.run("""
        try:
            \(expression)
            _raised = False
        except ValueError:
            _raised = True
        """)
        #expect(Interpreter.evaluate("_raised") == true)
    }

    @Test func optionsTakeTheirEnums() async throws {
        await Interpreter.run("""
        _stack = VStack("a", alignment=Alignment.TOP_LEADING)
        _scroll = ScrollView("b", axis=Axis.HORIZONTAL)
        _button = Button("Delete", role=ButtonRole.DESTRUCTIVE)
        _picker = Picker("Size", ["S"], style=PickerStyle.SEGMENTED)
        _styled = (Text("c").font(Font.LARGE_TITLE).padding(8, Edges.HORIZONTAL)
                   .foreground(Color.RED).background(Color.ACCENT).tint(Color.MINT)
                   .align(Alignment.LEADING))
        """)
        let stack: SwiftPyViews.VStack = try #require(py.main._stack)
        #expect(stack.alignment == "top-leading")
        let scroll: SwiftPyViews.ScrollView = try #require(py.main._scroll)
        #expect(scroll.axis == "horizontal")
        let button: SwiftPyViews.Button = try #require(py.main._button)
        #expect(button.role == "destructive")
        let picker: SwiftPyViews.Picker = try #require(py.main._picker)
        #expect(picker.style == "segmented")
        let styled: ModifiedView = try #require(py.main._styled)
        _ = styled.body()
    }

    @Test func buttonKeepsItsRole() async throws {
        await Interpreter.run("_button = Button('Delete', role='destructive')")
        let button: SwiftPyViews.Button = try #require(py.main._button)
        #expect(button.role == "destructive")
    }
}
