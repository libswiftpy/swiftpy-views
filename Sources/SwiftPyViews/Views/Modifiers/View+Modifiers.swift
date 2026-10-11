//
//  View+Modifiers.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

// Bound on `View` itself, so Python subclasses have them too. A binding is a
// C function, which can't capture: each one hands its modifier to `modify`.
@MainActor
enum ViewModifiers {
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        let view = PyType.View

        view.function(
            "padding(self, length: float | None = None, edges: Edges | str = 'all') -> View",
            "Adds space around the view: `length` points, or a size that suits it."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let length = try Double?.cast(arguments, 1)
                let edges = try Edge.Set(pythonName: String.cast(arguments, 2))
                return { AnyView($0.padding(edges, length.map { CGFloat($0) })) }
            }
        }

        view.function(
            "align(self, alignment: Alignment | str) -> View",
            "Fills the available space along the alignment's axes and places the view in it, such as \"leading\" or \"top-trailing\"."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let alignment = try String.cast(arguments, 1)
                let horizontal = Alignment.horizontal(alignment)
                let vertical = Alignment.vertical(alignment)
                return {
                    AnyView($0.frame(
                        maxWidth: horizontal == nil ? nil : .infinity,
                        maxHeight: vertical == nil ? nil : .infinity,
                        alignment: SwiftUI.Alignment(horizontal: horizontal ?? .center, vertical: vertical ?? .center)
                    ))
                }
            }
        }

        view.function(
            "font(self, font: Font | str, *, monospaced: bool = False) -> View",
            "Sets the text style of the text inside."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let font = try Font(pythonName: String.cast(arguments, 1))
                let monospaced = try Bool.cast(arguments, 2)
                return { AnyView($0.font(monospaced ? font.monospaced() : font)) }
            }
        }

        view.function("bold(self) -> View", "Makes the text inside bold.") { receiver, args in
            modify(receiver, args) { _ in { AnyView($0.bold()) } }
        }

        view.function("italic(self) -> View", "Makes the text inside italic.") { receiver, args in
            modify(receiver, args) { _ in { AnyView($0.italic()) } }
        }

        view.function(
            "foreground(self, color: Color | str) -> View",
            "Colors the text and symbols inside: a name such as \"red\" or \"secondary\", or \"#RRGGBB\"."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let color = try Color(pythonName: String.cast(arguments, 1))
                return { AnyView($0.foregroundStyle(color)) }
            }
        }

        view.function(
            "background(self, content: Color | str | View) -> View",
            "Puts a color, by name or \"#RRGGBB\", or a view behind the view."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let content = try PyObject.cast(arguments, 1)
                if let name = String(content) {
                    let color = try Color(pythonName: name)
                    return { AnyView($0.background(color)) }
                }
                return { AnyView($0.background { content.asView }) }
            }
        }

        view.function(
            "tint(self, color: Color | str) -> View",
            "Colors the controls inside: a name such as \"blue\", or \"#RRGGBB\"."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let color = try Color(pythonName: String.cast(arguments, 1))
                return { AnyView($0.tint(color)) }
            }
        }

        view.function(
            "disabled(self, disabled: bool = True) -> View",
            "Turns off the controls inside."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let disabled = try Bool.cast(arguments, 1)
                return { AnyView($0.disabled(disabled)) }
            }
        }

        view.function(
            "on_appear(self, action: Callable[[], Any]) -> View",
            "Calls `action` when the view appears."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let action = try PyObject.cast(arguments, 1)
                return { AnyView($0.onAppear { action.callback() }) }
            }
        }

        view.function(
            "toolbar(self, *items: View | str) -> View",
            "Shows the items in the toolbar of the window the view is in."
        ) { receiver, args in
            modify(receiver, args) { arguments in
                let items = try PyTuple.cast(arguments, 1).values
                return { view in
                    AnyView(view.toolbar {
                        ForEach(items.indices, id: \.self) { index in
                            items[index].asView
                        }
                    })
                }
            }
        }
    }
}

/// Wraps the receiver in a ``ModifiedView`` that applies what `make` reads
/// out of the arguments; argument 0 is the receiver.
@MainActor
private func modify(
    _ receiver: PyArguments.RawFirst,
    _ args: PyArguments.RawSecond,
    _ make: (PyArguments) throws -> @MainActor (AnyView) -> AnyView
) -> PyReturn {
    PyAPI.return {
        let arguments = PyArguments(method: receiver, args)
        let content = try PyObject.cast(arguments, 0)
        return ModifiedView(content: content, modifier: try make(arguments))
    }
}
