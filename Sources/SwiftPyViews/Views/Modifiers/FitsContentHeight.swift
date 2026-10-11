//
//  FitsContentHeight.swift
//  swiftpy-views
//

import SwiftUI

// A scrolling view, a form or list, given no height of its own, as in a
// notebook's scroll view, is as tall as what it holds rather than none.
private struct FitsContentHeight: ViewModifier {
    let cache: ContentHeight
    @State private var contentHeight: CGFloat?

    // A lazy stack recreates the view scrolled back into it: it starts at the
    // height measured before, rather than at 300, and doesn't move the scroll.
    init(cache: ContentHeight) {
        self.cache = cache
        _contentHeight = State(initialValue: cache.height)
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
            } action: { _, height in
                // Before its first layout a list reports none, which would
                // leave it no height to lay out in.
                if height > 0 {
                    contentHeight = height
                    cache.height = height
                }
            }
            // Ideal only: a height that's offered still wins. A list lays out
            // rows only in the height it has, so it starts with some to measure.
            .frame(idealHeight: contentHeight ?? 300)
            .scrollBounceBehavior(.basedOnSize)
    }
}

// Kept by the view's model, which outlives the SwiftUI view.
@MainActor
final class ContentHeight {
    var height: CGFloat?
}

extension View {
    func fitsContentHeight(_ cache: ContentHeight) -> some View {
        modifier(FitsContentHeight(cache: cache))
    }
}
