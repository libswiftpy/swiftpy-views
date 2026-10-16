//
//  Sizing.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A view given a size, or limits on one. Each can be changed later; None
/// leaves it to the view.
@Scriptable(base: .View)
@MainActor
@Observable
final class Sizing {
    /// The view, or a string to show as text.
    var content: PyObject
    /// Its width: points, or a `Percent` of the nearest `SizeContainer`'s width.
    var width: Length?
    /// Its height: points, or a `Percent` of the nearest `SizeContainer`'s height.
    var height: Length?
    /// The narrowest it gets.
    var minWidth: Length?
    /// The widest it gets.
    var maxWidth: Length?
    /// The shortest it gets.
    var minHeight: Length?
    /// The tallest it gets.
    var maxHeight: Length?

    /// Creates a sized view.
    ///
    /// content: A view, or a string to show as text.
    /// width: Points, or a `Percent` of the nearest `SizeContainer`'s width. Defaults to None, the view's own.
    /// height: Points, or a `Percent` of the nearest `SizeContainer`'s height. Defaults to None, the view's own.
    /// min_width: The narrowest it gets. Defaults to None.
    /// max_width: The widest it gets. Defaults to None.
    /// min_height: The shortest it gets. Defaults to None.
    /// max_height: The tallest it gets. Defaults to None.
    init(
        content: PyObject,
        width: Length? = nil,
        height: Length? = nil,
        minWidth: Length? = nil,
        maxWidth: Length? = nil,
        minHeight: Length? = nil,
        maxHeight: Length? = nil
    ) {
        self.content = content
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    func body() -> AnyView {
        AnyView(SizingContent(model: self))
    }
}

extension Sizing {
    static func installModifier(on view: PyType) {
        view.function(
            "size(self, width: Length | None = None, height: Length | None = None, min_width: Length | None = None, max_width: Length | None = None, min_height: Length | None = None, max_height: Length | None = None) -> Sizing",
            "Sizes the view, as a `Sizing` whose sizes can be changed later: points, or a `Percent` of the nearest `SizeContainer`. None leaves one to the view."
        ) { receiver, args in
            PyAPI.return {
                let arguments = PyArguments(method: receiver, args)
                return Sizing(
                    content: try PyObject.cast(arguments, 0),
                    width: try Length?.cast(arguments, 1),
                    height: try Length?.cast(arguments, 2),
                    minWidth: try Length?.cast(arguments, 3),
                    maxWidth: try Length?.cast(arguments, 4),
                    minHeight: try Length?.cast(arguments, 5),
                    maxHeight: try Length?.cast(arguments, 6)
                )
            }
        }
    }
}

private struct SizingContent: View {
    let model: Sizing
    @Environment(\.sizeReference) private var reference

    var body: some View {
        let minWidth = horizontal(model.minWidth)
        let minHeight = vertical(model.minHeight)
        // A maximum below the minimum would contradict it, which SwiftUI logs.
        let maxWidth = horizontal(model.maxWidth).map { max($0, minWidth ?? 0) }
        let maxHeight = vertical(model.maxHeight).map { max($0, minHeight ?? 0) }

        (model.content.asView ?? AnyView(EmptyView()))
            .frame(width: horizontal(model.width), height: vertical(model.height))
            .frame(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight)
    }

    // Never below 0, which SwiftUI would log as an invalid frame.
    private func horizontal(_ length: Length?) -> CGFloat? {
        length?.resolve(against: reference.width).map { max(0, $0) }
    }

    private func vertical(_ length: Length?) -> CGFloat? {
        length?.resolve(against: reference.height).map { max(0, $0) }
    }
}
