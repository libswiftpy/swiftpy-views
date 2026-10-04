//
//  PlatformStyle.swift
//  swiftpy-views
//

import SwiftUI

// Liquid Glass and a few related APIs are missing on visionOS, which has its
// own glass built into the standard styles. Every platform difference of that
// kind lives here, so views read the same everywhere. Surfaces flat on a window
// take a material there, as its glass on the window's glass barely shows; raised
// ones take glass, as a material shows nothing with no window behind it.
public extension EnvironmentValues {
    /// Whether content is lifted off the window, which ``raisedOffWindow(by:)`` sets.
    @Entry var surfacesAreRaised = false
}

public extension View {
    /// Lifts the view toward the viewer on visionOS, its surfaces in glass.
    /// Elsewhere, the view as it is.
    func raisedOffWindow(by depth: CGFloat = 16) -> some View {
        #if os(visionOS)
        environment(\.surfacesAreRaised, true)
            .offset(z: depth)
        #else
        self
        #endif
    }

    /// The glass behind a surface on visionOS, by whether it's raised.
    @ViewBuilder
    private func visionSurface(in shape: some InsettableShape) -> some View {
        #if os(visionOS)
        modifier(VisionSurface(shape: shape))
        #else
        self
        #endif
    }
}

public extension View {
    /// A suggestion chip's style: `.glass` where it exists; on visionOS, raised,
    /// the glass the signature help above it has, else `.bordered`.
    func glassChipStyle() -> some View {
        #if os(visionOS)
        modifier(VisionChipStyle())
        #else
        glassButtonStyle()
        #endif
    }
}

#if os(visionOS)
private struct VisionChipStyle: ViewModifier {
    @Environment(\.surfacesAreRaised) private var isRaised

    func body(content: Content) -> some View {
        if isRaised {
            content.buttonStyle(RaisedGlassChip())
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct RaisedGlassChip: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassBackgroundEffect(in: .capsule)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect()
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

private struct VisionSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.surfacesAreRaised) private var isRaised

    func body(content: Content) -> some View {
        if isRaised {
            content.glassBackgroundEffect(in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}
#endif

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
                .visionSurface(in: .rect(cornerRadius: cornerRadius))
                #else
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                #endif
        }
    }

    /// A non-interactive glass background, in each platform's own glass.
    func glassBackground(in shape: some InsettableShape) -> some View {
        #if os(visionOS)
        visionSurface(in: shape)
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
