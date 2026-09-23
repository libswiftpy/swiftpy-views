//
//  PlatformStyle.swift
//  swiftpy-views
//

import SwiftUI

// Liquid Glass and a few related APIs are missing on visionOS, which has its
// own glass built into the standard styles. Every platform difference of that
// kind lives here, so views read the same everywhere.
public extension View {
    /// `.glass` where it exists, `.bordered` on visionOS.
    func glassButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.glass)
        #endif
    }

    /// `.glass(.clear)` where it exists, `.borderless` on visionOS.
    func clearGlassButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.borderless)
        #else
        buttonStyle(.glass(.clear))
        #endif
    }

    /// An interactive glass surface, in each platform's own glass.
    func glassSurface(cornerRadius: CGFloat, onTap: @escaping () -> Void) -> some View {
        background {
            Color.clear
                .contentShape(.rect(cornerRadius: cornerRadius))
                .onTapGesture(perform: onTap)
                #if os(visionOS)
                .glassBackgroundEffect(in: .rect(cornerRadius: cornerRadius))
                #else
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                #endif
        }
    }

    /// A non-interactive glass background, in each platform's own glass.
    /// visionOS insets its glass, so the shape has to be insettable.
    func glassBackground(in shape: some InsettableShape) -> some View {
        #if os(visionOS)
        glassBackgroundEffect(in: shape)
        #else
        glassEffect(in: shape)
        #endif
    }

    /// Lets a scroll dismiss the keyboard where there is one to dismiss.
    func dismissesKeyboardOnScroll() -> some View {
        #if os(visionOS)
        self
        #else
        scrollDismissesKeyboard(.interactively)
        #endif
    }

    /// A trailing inspector, or a sheet on visionOS, which has no inspector.
    func inspectorOrSheet<Inspector: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Inspector
    ) -> some View {
        #if os(visionOS)
        sheet(isPresented: isPresented) {
            ClosableSheet(content: content)
        }
        #else
        inspector(isPresented: isPresented) {
            content()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
        }
        #endif
    }
}

/// A fixed toolbar gap where `ToolbarSpacer` exists; nothing on visionOS.
public struct FixedToolbarSpacer: ToolbarContent {
    public init() {}

    public var body: some ToolbarContent {
        #if os(visionOS)
        ToolbarItem { EmptyView() }
        #else
        ToolbarSpacer(.fixed)
        #endif
    }
}

// A visionOS sheet can't be swiped away, so it brings its own close.
private struct ClosableSheet<Body: View>: View {
    @ViewBuilder let content: () -> Body
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content()
                .toolbar {
                    SwiftUI.Button(role: .close) { dismiss() }
                }
        }
    }
}
