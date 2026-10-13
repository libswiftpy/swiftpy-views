//
//  Form.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// Controls and sections, laid out as a settings screen.
@Scriptable(base: .View)
@Observable
@MainActor
final class Form {
    /// The views, which can be changed after it's made.
    let content: Group

    /// Creates a form.
    ///
    /// content: Sections, views, or strings to show as text.
    init(content: Unpack) {
        self.content = Group(objects: content.values)
    }

    func body() -> AnyView {
        AnyView(FormContent(model: self))
    }
}

private struct FormContent: View {
    let model: Form

    var body: some View {
        SquareWhenUnbounded {
            SwiftUI.Form {
                model.content.body()
            }
            .formStyle(.grouped)
            // Its grouped background, rounded to sit in a card.
            .clipShape(ConcentricRectangle.followingCorners)
        }
        .fillsAvailableSpace()
    }
}

// A form has no height of its own: given none, as in a notebook, it's as
// tall as it is wide, and scrolls within that.
private struct SquareWhenUnbounded: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 320
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? width
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
