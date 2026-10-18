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
    /// Its width over its height, such as 1 for a square: the other side follows
    /// from the one given, and with neither, it fits the space it's offered.
    var aspectRatio: Double?

    /// Creates a sized view.
    ///
    /// content: A view, or a string to show as text.
    /// width: Points, or a `Percent` of the nearest `SizeContainer`'s width. Defaults to None, the view's own.
    /// height: Points, or a `Percent` of the nearest `SizeContainer`'s height. Defaults to None, the view's own.
    /// min_width: The narrowest it gets. Defaults to None.
    /// max_width: The widest it gets. Defaults to None.
    /// min_height: The shortest it gets. Defaults to None.
    /// max_height: The tallest it gets. Defaults to None.
    /// aspect_ratio: Its width over its height, such as 1 for a square. Defaults to None.
    init(
        content: PyObject,
        width: Length? = nil,
        height: Length? = nil,
        minWidth: Length? = nil,
        maxWidth: Length? = nil,
        minHeight: Length? = nil,
        maxHeight: Length? = nil,
        aspectRatio: Double? = nil
    ) {
        self.content = content
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.aspectRatio = aspectRatio
    }

    func body() -> AnyView {
        AnyView(SizingContent(model: self))
    }
}

extension Sizing {
    static func installModifier(on view: PyType) {
        view.function(
            "size(self, width: Length | None = None, height: Length | None = None, min_width: Length | None = None, max_width: Length | None = None, min_height: Length | None = None, max_height: Length | None = None, aspect_ratio: float | None = None) -> Sizing",
            "Sizes the view, as a `Sizing` whose sizes can be changed later: points, or a `Percent` of the nearest `SizeContainer`. None leaves one to the view. `aspect_ratio`, width over height, gives the side left out, as in `size(width=Percent(30), aspect_ratio=1)` for a square."
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
                    maxHeight: try Length?.cast(arguments, 6),
                    aspectRatio: try Double?.cast(arguments, 7)
                )
            }
        }
    }
}

extension Sizing {
    /// The side left out, from the one given and the ratio; both given win.
    static func size(width: CGFloat?, height: CGFloat?, aspectRatio: Double?) -> (width: CGFloat?, height: CGFloat?) {
        guard let ratio = validRatio(aspectRatio) else { return (width, height) }
        switch (width, height) {
        case let (width?, nil): return (width, width / ratio)
        case let (nil, height?): return (height * ratio, height)
        default: return (width, height)
        }
    }

    // A ratio of 0 or less, or not a number, has no shape to keep.
    static func validRatio(_ ratio: Double?) -> CGFloat? {
        guard let ratio, ratio.isFinite, ratio > 0 else { return nil }
        return CGFloat(ratio)
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

        let size = Sizing.size(width: horizontal(model.width), height: vertical(model.height), aspectRatio: model.aspectRatio)

        content
            .frame(width: size.width, height: size.height)
            .frame(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight)
    }

    // With neither side given, as large as fits.
    @ViewBuilder private var content: some View {
        let view = model.content.asView ?? AnyView(EmptyView())
        if let ratio = Sizing.validRatio(model.aspectRatio), model.width == nil, model.height == nil {
            view.aspectRatio(ratio, contentMode: .fit)
        } else {
            view
        }
    }

    // Never below 0, which SwiftUI would log as an invalid frame.
    private func horizontal(_ length: Length?) -> CGFloat? {
        length?.resolve(against: reference.width).map { max(0, $0) }
    }

    private func vertical(_ length: Length?) -> CGFloat? {
        length?.resolve(against: reference.height).map { max(0, $0) }
    }
}
