//
//  ViewSnapshot.swift
//  swiftpy-views
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Draws a view by hosting it in a window, so views backed by UIKit or AppKit
/// (text fields, scroll views, Markdown) draw too, which `ImageRenderer` can't.
@MainActor
enum ViewSnapshot {
    static func image(of view: AnyView, width: CGFloat?, delay: Double, background: Color?) async -> PlatformImage {
        #if canImport(UIKit)
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.keyWindow != nil }
        guard let scene, let keyWindow = scene.keyWindow else {
            return rendered(view, width: width ?? 393, background: background)
        }
        let width = width ?? keyWindow.bounds.width
        let controller = UIHostingController(rootView: sized(view, width: width, background: background))
        controller.safeAreaRegions = []
        controller.view.backgroundColor = .clear

        // Behind the app's own window, so it's never seen.
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.isUserInteractionEnabled = false
        window.backgroundColor = .clear
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        func fit() {
            let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
            window.frame = CGRect(x: 0, y: 0, width: width, height: max(1, ceil(size.height)))
            window.layoutIfNeeded()
        }
        fit()
        await settle(delay)
        fit()

        let format = UIGraphicsImageRendererFormat(for: window.traitCollection)
        format.opaque = false
        let bounds = controller.view.bounds
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
            controller.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        #else
        let width = width ?? NSApp?.keyWindow?.contentLayoutRect.width ?? 400
        let host = NSHostingView(rootView: sized(view, width: width, background: background))
        host.safeAreaRegions = []

        // Never ordered front: drawing into a bitmap doesn't need it on screen.
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: width, height: 1),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.contentView = host

        func fit() {
            host.layoutSubtreeIfNeeded()
            window.setContentSize(CGSize(width: width, height: max(1, ceil(host.fittingSize.height))))
            host.layoutSubtreeIfNeeded()
        }
        fit()
        await settle(delay)
        fit()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return rendered(view, width: width, background: background)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(bitmap)
        return image
        #endif
    }

    // Leading, as a card lays out its output, at its ideal height: a ScrollView
    // takes its content's, but a List has none, so it needs a frame.
    // Without a colour, the app's background, which resolves to light or dark in the window.
    private static func sized(_ view: AnyView, width: CGFloat, background: Color?) -> some View {
        view
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .background(background ?? appBackground)
    }

    private static var appBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    // A couple of frames, so appearing and `.task` work gets going, then `delay`.
    private static func settle(_ delay: Double) async {
        try? await Task.sleep(for: .milliseconds(33) + .seconds(max(0, delay)))
    }

    // Without a window to host it in, as in tests without an app.
    private static func rendered(_ view: AnyView, width: CGFloat, background: Color?) -> PlatformImage {
        let renderer = ImageRenderer(content: sized(view, width: width, background: background))
        #if canImport(UIKit)
        renderer.scale = max(1, UITraitCollection.current.displayScale)
        return renderer.uiImage ?? UIImage()
        #else
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage ?? NSImage()
        #endif
    }
}

extension PlatformImage {
    var png: Data? {
        #if canImport(UIKit)
        pngData()
        #else
        guard let image = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        #endif
    }
}
