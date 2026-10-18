//
//  ScrollView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-02.
//

import SwiftPy
import SwiftUI

/// A view that scrolls its views when they don't fit.
@Scriptable(base: .View)
@Observable
@MainActor
final class ScrollView {
    /// The views, which can be changed after it's made.
    let content: Group
    /// The direction it scrolls: an `Axis`, or its name.
    var axis: AxisValue
    internal let contentHeight = ContentHeight()

    /// Creates a scroll view.
    ///
    /// content: Views, or strings to show as text.
    /// axis: The direction it scrolls: an `Axis`, such as `Axis.HORIZONTAL`, or its name. Defaults to vertical.
    init(content: Unpack, axis: AxisValue = "vertical") {
        self.content = Group(objects: content.values)
        self.axis = axis
    }

    func body() -> AnyView {
        AnyView(ScrollViewContent(model: self))
    }
}

private struct ScrollViewContent: View {
    let model: ScrollView
    @State private var offered = OfferedLengths()
    @State private var reference = SizeReference()

    var body: some View {
        OfferedLengthsLayout(offered: offered) {
            if model.axis.name == "horizontal" {
                SwiftUI.ScrollView(.horizontal) {
                    SwiftUI.HStack { contentInReference }
                }
            } else {
                SwiftUI.ScrollView {
                    SwiftUI.VStack { contentInReference }
                }
                .fitsContentHeight(model.contentHeight)
            }
        }
        // After layout, so the lengths it was offered are known.
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            reference = SizeReference(
                width: offered.width ? size.width : nil,
                height: offered.height ? size.height : nil
            )
        }
    }

    // Percentages inside are of what's visible, on an axis it was offered a
    // length on: one it takes from its content would size the content from itself.
    // A SizeContainer inside measures against it too, not a card around it.
    private var contentInReference: some View {
        model.content.body()
            .environment(\.sizeReference, reference)
            .environment(\.sizeContainerUnboundedAxis, .visibleLength)
    }
}

/// Which axes a view was offered a length on. Written by layout, which runs
/// on main, outside the main actor's checks.
private final class OfferedLengths: @unchecked Sendable {
    var width = false
    var height = false
}

/// Takes the lengths its parent offers, so a reference of them doesn't depend
/// on the content, and notes which they were as it places what it holds.
private struct OfferedLengthsLayout: Layout {
    let offered: OfferedLengths

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let fitted = subviews.first?.sizeThatFits(proposal) ?? .zero
        return CGSize(
            width: proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? fitted.width,
            height: proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? fitted.height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        offered.width = proposal.width?.isFinite ?? false
        offered.height = proposal.height?.isFinite ?? false
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
