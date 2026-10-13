//
//  Widget.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A home-screen widget, previewed in each of its sizes.
@Scriptable(base: .View)
@MainActor
@Observable
final class Widget {
    /// A view, or a function called with each `WidgetSize` that returns one.
    var content: PyObject
    /// The sizes the widget comes in.
    let sizes: [String]
    /// Seconds between rebuilding the content, or None to build it once.
    var refresh: Double?

    // Bumped by `reload()`, which restarts the preview's builds.
    internal var reloads = 0
    internal let names: [WidgetSizeName]

    /// Creates a widget.
    ///
    /// content: A view, or a function called with each `WidgetSize` that returns one.
    /// sizes: The `WidgetSize`s it comes in. Defaults to small only.
    /// refresh: Seconds between rebuilding the content, like a widget's reload policy. Defaults to None, which builds it once.
    init(content: PyObject, sizes: [String]? = nil, refresh: Double? = nil) throws {
        let sizes = sizes ?? ["small"]
        guard !sizes.isEmpty else { throw PythonError.ValueError("a widget needs at least one size") }
        self.names = try sizes.map(WidgetSizeName.init(pythonName:))
        self.content = content
        self.sizes = sizes
        self.refresh = refresh
    }

    /// Builds the content again now, as `WidgetCenter.reloadTimelines` does for a real widget.
    func reload() {
        reloads += 1
    }

    func body() -> AnyView {
        AnyView(WidgetPreview(model: self))
    }

    /// The content function's view for `size`, or what went wrong.
    internal func build(_ size: WidgetSizeName) async -> Built {
        do {
            guard let member: PyObject = try py.module("widgets")?.WidgetSize?(size.rawValue) else {
                throw PythonError.RuntimeError("the widgets module is missing")
            }
            let view = try await Self.call(content, with: member)
            guard let body = view.asView else {
                throw PythonError.TypeError("a widget's content returned \(view.typeName), not a view")
            }
            return .view(body)
        } catch {
            return .failure(String(describing: error).replacing(/\u{1B}\[[0-9;]*m/, with: ""))
        }
    }

    // On the Python thread, as a cell runs, so a blocking call like
    // requests.get can wait there; main can't.
    @PythonActor
    private static func call(_ function: PyObject, with size: PyObject) throws -> PyObject {
        try PyRuntime.call(function, arguments: [size])
    }
}

enum WidgetSizeName: String, CaseIterable {
    case small, medium, large, extraLarge = "extra_large"

    init(pythonName name: String) throws {
        guard let size = Self(rawValue: name) else {
            throw PythonError.ValueError("unknown widget size: \(name)")
        }
        self = size
    }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    /// The size on a screen `width` points wide in portrait, from Apple's
    /// widget size tables, by the closest width listed.
    func size(onScreenWidth width: CGFloat) -> CGSize {
        // (screen width, small side, wide width, large height, extra large width)
        let rows: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (320, 141, 292, 311, 0),
            (360, 149, 316, 332, 0),
            (375, 155, 329, 345, 0),
            (390, 158, 338, 354, 0),
            (393, 158, 338, 354, 0),
            (414, 169, 360, 379, 0),
            (428, 170, 364, 382, 0),
            (430, 170, 364, 382, 0),
            // iPad, where the extra large size exists.
            (744, 141, 305, 305, 634),
            (768, 141, 305, 305, 634),
            (810, 146, 320, 320, 669),
            (820, 155, 342, 342, 715),
            (834, 155, 342, 342, 715),
            (1024, 170, 379, 379, 795),
        ]
        let row = rows.min { abs($0.0 - width) < abs($1.0 - width) }!
        let extraLarge = row.4 > 0 ? row.4 : row.2 * 2 + 20
        return switch self {
        case .small: CGSize(width: row.1, height: row.1)
        case .medium: CGSize(width: row.2, height: row.1)
        case .large: CGSize(width: row.2, height: row.3)
        case .extraLarge: CGSize(width: extraLarge, height: row.3)
        }
    }
}

/// What a content function built for one size.
enum Built {
    case view(AnyView)
    case failure(String)
}

private struct WidgetPreview: View {
    let model: Widget
    @State private var built: [WidgetSizeName: Built] = [:]

    var body: some View {
        SwiftUI.VStack(spacing: 16) {
            ForEach(model.names, id: \.self) { size in
                SwiftUI.VStack(spacing: 8) {
                    WidgetFrame(size: size) {
                        content(for: size)
                    }
                    SwiftUI.Text(size.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .task(id: model.reloads) { await buildWhileShown() }
    }

    @ViewBuilder
    private func content(for size: WidgetSizeName) -> some View {
        if let view = model.content.asView {
            view
        } else {
            switch built[size] {
            case .view(let view): view
            case .failure(let message):
                SwiftUI.Text(message)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.red)
            case nil: EmptyView()
            }
        }
    }

    /// Builds each size, then again every `refresh` seconds while shown.
    private func buildWhileShown() async {
        // A view is its own content; only a function is built.
        guard model.content.asView == nil else { return }
        while !Task.isCancelled {
            for size in model.names {
                built[size] = await model.build(size)
            }
            guard let refresh = model.refresh, refresh > 0 else { return }
            try? await Task.sleep(for: .seconds(refresh))
        }
    }
}

/// A widget's shape and size as the home screen draws it.
private struct WidgetFrame<Content: View>: View {
    let size: WidgetSizeName
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let frame = size.size(onScreenWidth: Self.screenWidth)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        content
            .padding(16)
            .frame(width: frame.width, height: frame.height)
            .clipShape(shape)
            // On the shape alone, or the text would cast one too.
            .background {
                shape
                    .fill(colorScheme == .dark ? Color(white: 0.11) : .white)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
            // What a ContainerRelativeShape in the content follows, as in a real widget.
            .containerShape(shape)
    }

    /// The device's screen width in portrait, which widget sizes go by.
    private static var screenWidth: CGFloat {
        #if canImport(UIKit)
        let screen = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
            .first
        guard let bounds = screen?.bounds else { return 393 }
        return min(bounds.width, bounds.height)
        #else
        // The Mac's widgets are the largest phone's sizes.
        return 430
        #endif
    }
}
