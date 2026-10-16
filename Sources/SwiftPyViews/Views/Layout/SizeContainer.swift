//
//  SizeContainer.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A view that fills the space it's given, and that `Percent` lengths inside
/// it are of, through stacks and scroll views; a nested one starts its own.
/// Where it's offered no length, as down a scroll view, it takes the scroll
/// view's visible length; in a notebook card, it's square.
@Scriptable(base: .View)
@MainActor
@Observable
final class SizeContainer {
    /// The view, or a string to show as text.
    var content: PyObject
    /// Where the content sits in it: an `Alignment`, such as `Alignment.TOP_LEADING`, or its name.
    var alignment: AlignmentValue

    /// Creates a size container.
    ///
    /// content: A view, or a string to show as text.
    /// alignment: Where the content sits in it: an `Alignment`, such as `Alignment.TOP_LEADING`, or its name. Defaults to center.
    init(content: PyObject, alignment: AlignmentValue = "center") {
        self.content = content
        self.alignment = alignment
    }

    func body() -> AnyView {
        AnyView(SizeContainerContent(model: self))
    }
}

private struct SizeContainerContent: View {
    let model: SizeContainer
    @Environment(\.sizeContainerUnboundedAxis) private var unbounded
    @State private var visible: CGSize?

    var body: some View {
        SizeContainerLayout(unbounded: unbounded, visible: visible) {
            // Measures in the same pass, so the content resolves against it.
            GeometryReader { proxy in
                (model.content.asView ?? AnyView(EmptyView()))
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: Alignment.both(model.alignment.name))
                    .environment(\.sizeReference, SizeReference(width: proxy.size.width, height: proxy.size.height))
            }
        }
        .onGeometryChange(for: CGSize?.self) { $0.bounds(of: .scrollView)?.size } action: { visible = $0 }
    }
}

/// Takes the length offered on each axis; one offered none comes from
/// `unbounded`.
private struct SizeContainerLayout: Layout {
    let unbounded: SizeContainerUnboundedAxis
    let visible: CGSize?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap(finite)
        let height = proposal.height.flatMap(finite)
        switch (width, height) {
        case let (width?, height?):
            return CGSize(width: width, height: height)
        case let (width?, nil):
            return CGSize(width: width, height: length(across: width, visible: visible?.height, invert: false))
        case let (nil, height?):
            return CGSize(width: length(across: height, visible: visible?.width, invert: true), height: height)
        case (nil, nil):
            return visible ?? .zero
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }

    /// One axis's length, from the other's.
    private func length(across other: CGFloat, visible: CGFloat?, invert: Bool) -> CGFloat {
        switch unbounded {
        case .visibleLength:
            visible ?? other
        case .aspectRatio(let ratio):
            invert ? other * ratio : other / max(ratio, .ulpOfOne)
        }
    }

    private func finite(_ length: CGFloat) -> CGFloat? {
        length.isFinite ? length : nil
    }
}
