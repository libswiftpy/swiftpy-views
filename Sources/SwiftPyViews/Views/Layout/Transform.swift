//
//  Transform.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A view offset from where the layout puts it. The offset doesn't change the
/// space its container gives it, and can be changed later, and animated with
/// `animate`.
@Scriptable(base: .View)
@MainActor
@Observable
final class Transform {
    /// The view, or a string to show as text.
    var content: PyObject
    /// Points to the right, or a `Percent` of the nearest `SizeContainer`'s width.
    var x: Length
    /// Points down, or a `Percent` of the nearest `SizeContainer`'s height.
    var y: Length

    /// Creates an offset view.
    ///
    /// content: A view, or a string to show as text.
    /// x: Points to the right, or a `Percent` of the nearest `SizeContainer`'s width. Defaults to 0.
    /// y: Points down, or a `Percent` of the nearest `SizeContainer`'s height. Defaults to 0.
    init(content: PyObject, x: Length = 0, y: Length = 0) {
        self.content = content
        self.x = x
        self.y = y
    }

    func body() -> AnyView {
        AnyView(TransformContent(model: self))
    }
}

extension Transform {
    static func installModifier(on view: PyType) {
        view.function(
            "transform(self, x: Length = 0, y: Length = 0) -> Transform",
            "Offsets the view from where the layout puts it, as a `Transform` whose `x` and `y` can be changed later."
        ) { receiver, args in
            PyAPI.return {
                let arguments = PyArguments(method: receiver, args)
                return Transform(
                    content: try PyObject.cast(arguments, 0),
                    x: try Length?.cast(arguments, 1) ?? 0,
                    y: try Length?.cast(arguments, 2) ?? 0
                )
            }
        }
    }
}

private struct TransformContent: View {
    let model: Transform
    @Environment(\.sizeReference) private var reference

    var body: some View {
        (model.content.asView ?? AnyView(EmptyView()))
            .offset(
                x: model.x.resolve(against: reference.width) ?? 0,
                y: model.y.resolve(against: reference.height) ?? 0
            )
    }
}
