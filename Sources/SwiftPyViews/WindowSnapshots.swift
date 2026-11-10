//
//  WindowSnapshots.swift
//  swiftpy-views
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Small pictures of Python windows as they look, for a host to show them by.
@MainActor
@Observable
public final class WindowSnapshots {
    public static let shared = WindowSnapshots()

    public private(set) var images: [String: SwiftUI.Image] = [:]
    #if canImport(UIKit)
    @ObservationIgnored private var windows: [String: Weak<UIWindow>] = [:]
    #elseif canImport(AppKit)
    @ObservationIgnored private var windows: [String: Weak<NSWindow>] = [:]
    #endif

    /// Wide enough for a Home card, and cheap to keep.
    private static let width: CGFloat = 480

    /// Pictures every window shown now; call it while their pictures are on screen.
    public func refresh() {
        for id in windows.keys {
            capture(id)
        }
    }

    func capture(_ id: String) {
        guard let window = windows[id]?.value else {
            windows[id] = nil
            images[id] = nil
            return
        }
        #if canImport(UIKit)
        let bounds = window.bounds
        guard bounds.width > 0 else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(1, Self.width / bounds.width)
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            // Metal and RealityKit layers can come out blank.
            window.drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
        images[id] = SwiftUI.Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let view = window.contentView, view.bounds.width > 0,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        images[id] = SwiftUI.Image(nsImage: image)
        #endif
    }

    #if canImport(UIKit)
    fileprivate func track(_ window: UIWindow?, for id: String) {
        windows[id] = window.map(Weak.init)
    }
    #elseif canImport(AppKit)
    fileprivate func track(_ window: NSWindow?, for id: String) {
        windows[id] = window.map(Weak.init)
    }
    #endif

    fileprivate func forget(_ id: String) {
        windows[id] = nil
        images[id] = nil
    }
}

private final class Weak<Object: AnyObject> {
    weak var value: Object?
    init(_ value: Object) { self.value = value }
}

#if canImport(UIKit)
private struct WindowReader: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> ReaderView { ReaderView(id: id) }
    func updateUIView(_ view: ReaderView, context: Context) {}

    final class ReaderView: UIView {
        let id: String
        init(id: String) {
            self.id = id
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            WindowSnapshots.shared.track(window, for: id)
        }
    }
}
#elseif canImport(AppKit)
private struct WindowReader: NSViewRepresentable {
    let id: String

    func makeNSView(context: Context) -> ReaderView { ReaderView(id: id) }
    func updateNSView(_ view: ReaderView, context: Context) {}

    final class ReaderView: NSView {
        let id: String
        init(id: String) {
            self.id = id
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            WindowSnapshots.shared.track(window, for: id)
        }
    }
}
#endif

private struct WindowSnapshotsModifier: ViewModifier {
    let id: String
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .background(WindowReader(id: id).allowsHitTesting(false))
            // Its look as it's left, as Home comes forward.
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { WindowSnapshots.shared.capture(id) }
            }
            .onDisappear { WindowSnapshots.shared.forget(id) }
    }
}

extension View {
    func windowSnapshots(for id: String) -> some View {
        modifier(WindowSnapshotsModifier(id: id))
    }
}
