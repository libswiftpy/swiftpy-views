//
//  CompletionDropdownTests.swift
//  swiftpy-views
//

import Testing
import SwiftUI
@testable import SwiftPyViews

@MainActor
struct CompletionDropdownTests {
    private let container = CGRect(x: 100, y: 50, width: 600, height: 400)
    private let panel = CGSize(width: 300, height: 120)

    @Test func dropsBelowTheLineWithItsTextUnderTheWord() throws {
        let anchor = CGRect(x: 200, y: 100, width: 2, height: 20)
        let place = try #require(CompletionDropdownPlacement.place(anchor: anchor, container: container, panel: panel, leading: 25))
        #expect(place.origin.x == 75)
        #expect(place.origin.y == 74)
    }

    @Test func goesAboveWhereOnlyThatFits() throws {
        let anchor = CGRect(x: 200, y: 400, width: 2, height: 20)
        let place = try #require(CompletionDropdownPlacement.place(anchor: anchor, container: container, panel: panel, leading: 25))
        // The line starts at 350 in the container; the panel's bottom goes 4 above it.
        #expect(place.isAbove)
        #expect(abs(place.origin.y - 346) < 0.001)
    }

    @Test func staysWithinTheContainer() throws {
        let left = CGRect(x: 110, y: 100, width: 2, height: 20)
        #expect(CompletionDropdownPlacement.place(anchor: left, container: container, panel: panel, leading: 25)?.origin.x == 0)
        let right = CGRect(x: 690, y: 100, width: 2, height: 20)
        #expect(CompletionDropdownPlacement.place(anchor: right, container: container, panel: panel, leading: 25)?.origin.x == 292)
    }

    @Test func hidesWhileTheWordIsScrolledAway() {
        let gone = CGRect(x: 200, y: 10, width: 2, height: 20)
        #expect(CompletionDropdownPlacement.place(anchor: gone, container: container, panel: panel, leading: 25) == nil)
    }

    @Test func namesACallsParameters() {
        #expect(CodeSuggestion.parameterNames(in: "(*values: object, sep: str | None = \" \", end: str = \"\\n\")") == "(*values, sep, end)")
        #expect(CodeSuggestion.parameterNames(in: "(a: dict[str, int], b=(1, 2), **kw) -> None") == "(a, b, **kw)")
        #expect(CodeSuggestion.parameterNames(in: "()") == "()")
        #expect(CodeSuggestion.parameterNames(in: "no parens") == nil)
        // A method's receiver isn't passed; a declaration's name is skipped.
        #expect(CodeSuggestion.parameterNames(in: "def run(self, steps: int = 1) -> None") == "(steps)")
    }

    @Test func showsTheNameAfterTheQuerysDots() {
        #expect(CodeSuggestion(text: "os.path.join").displayName == "join")
        #expect(CodeSuggestion(text: "print(").displayName == "print")
        #expect(CodeSuggestion(text: "obj.run()").displayName == "run")
    }

    @Test func findsTheCallsOpenParen() {
        func paren(_ text: String) -> Int? {
            CodeTextView.openParen(in: text as NSString, before: (text as NSString).length)
        }
        #expect(paren("print(a, (b), ") == 5)
        #expect(paren("x = [1, f(2") == 9)
        // Inside a list, not a call.
        #expect(paren("f(a)[") == nil)
        #expect(paren("x = 1") == nil)
    }
}
