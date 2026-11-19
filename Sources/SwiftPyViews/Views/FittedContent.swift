//
//  FittedContent.swift
//  swiftpy-views
//

import SwiftUI

/// Content as a window or a preview shows it: centred when it fits, scrolling
/// along `axes` when it doesn't, and handed the space whole when it fills it
/// itself, as a scene or a list does. A scroll view would shrink such content
/// to its ideal size and cost it the safe area insets it gets in the layout.
public struct FittedContent<Content: View>: View {
    private let axes: Axis.Set
    private let padding: CGFloat
    private let content: Content
    @State private var fillsAvailableSpace = false

    public init(scrolling axes: Axis.Set = .vertical, padding: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        container
            .onPreferenceChange(FillsAvailableSpaceKey.self) { fills in
                fillsAvailableSpace = fills
            }
    }

    @ViewBuilder
    private var container: some View {
        if fillsAvailableSpace {
            content
        } else {
            ViewThatFits(in: axes) {
                content
                    .padding(padding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                SwiftUI.ScrollView(axes) {
                    if axes.contains(.horizontal) {
                        content.padding(padding)
                    } else {
                        content
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(padding)
                    }
                }
                .defaultScrollAnchor(.topLeading)
            }
        }
    }
}
