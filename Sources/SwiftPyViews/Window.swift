//
//  Window.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-10-30.
//

import SwiftPy
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A window that presents the views added to it.
@MainActor
@Observable
@Scriptable
class Window: Identifiable {
    struct ID: Codable, Hashable {
        let id: String
    }

    typealias object = PyAPI.Reference

    /// Title of the window's navigation stack.
    var title: String?

    /// Whether the window shows a close button.
    var closable: Bool = true

    /// Presents the window as a sheet instead of a fullscreen cover.
    var sheet: Bool = false

    private(set) var views: [PyObject] = []
    var destinations: [Destination] = []

    internal let id: ID
    /// Opened by a script, rather than by the host, as a docs page is.
    internal var isScript = true
    /// The notebook it was opened from.
    internal let owner: WindowOwner?

    struct Destination: Hashable {
        let id = UUID()
        let view: PyObject
        let title: String?

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    #if canImport(UIKit)
    // Weak: the presented controller's root view holds the window.
    @ObservationIgnored private weak var presentedController: UIViewController?

    /// Whether the window is a modal rather than a window of its own; observed,
    /// so its Close shows however early the content first draws.
    private(set) var isPresentedModally = false
    #endif

    /// Creates a window to present views in.
    ///
    /// content: A view to show. A string without a title is the title instead,
    ///   as `Window("Color Mixer")` has always been; `Text("…")` shows one. Defaults to None.
    /// title: Text the navigation stack shows. Defaults to None, which leaves the window untitled.
    /// closable: Whether the window shows a close button. Defaults to True.
    /// sheet: Presents the window as a sheet instead of a fullscreen cover. Defaults to False.
    init(content: PyObject? = nil, title: String? = nil, closable: Bool = true, sheet: Bool = false) {
        var content = content
        var title = title
        if title == nil, let text = content.flatMap({ String.isConvertible($0.reference) ? String.fromPython($0.reference) : nil }) {
            title = text
            content = nil
        }
        self.title = title
        self.closable = closable
        self.sheet = sheet
        id = ID(id: UUID().uuidString)
        owner = WindowActions.shared.owner
        if let content { views.append(content) }
        Window.windows[id] = self
    }

    /// Appends a view to the window's content.
    ///
    /// view: A view, or a string to show as text.
    func add(_ view: PyObject) {
        views.append(view)
    }

    // Not an `add` overload: the macro binds `add(_:)` by its unapplied
    // reference, which a second one of the same name makes ambiguous.
    internal func collect(_ view: AnyView) {
        guard let object = py.retain(view) else { return }
        views.append(object)
    }

    internal func navigate(title: String?, to view: AnyView) {
        guard let object = py.retain(view) else { return }
        destinations.append(Destination(view: object, title: title))
    }

    /// Pushes a view onto the window's navigation stack.
    ///
    /// view: A view, or a string to show as text.
    func push(_ view: PyObject) {
        destinations.append(Destination(view: view, title: nil))

        if !Window.presentedWindows.contains(id) {
            show()
        }
    }

    /// Presents the window.
    func show() {
        Interpreter.reportWindowShown()
        #if os(macOS)
        let opensWindow = true
        #else
        let opensWindow = !sheet
        #endif
        if opensWindow, let openWindow = WindowActions.shared.openWindow {
            openWindow(value: id)
            Window.presentedWindows.insert(id)
            return
        }
        #if os(macOS)
        let environment = EnvironmentValues()
        if environment.supportsMultipleWindows {
            environment.openWindow(value: id)
            Window.presentedWindows.insert(id)
            return
        }
        #endif

        #if canImport(UIKit)
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap(\.keyWindow)
            .first

        var topController = keyWindow?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }

        let controller = UIHostingController(rootView: WindowContent(window: self))
        controller.modalPresentationStyle = sheet ? .pageSheet : .fullScreen
        // A window without a close button can't be swiped away either.
        controller.isModalInPresentation = !closable

        presentedController = controller
        isPresentedModally = true
        topController?.present(controller, animated: true)
        Window.presentedWindows.insert(id)
        #endif
    }

    /// Dismisses the window.
    func close() {
        #if canImport(UIKit)
        if let controller = presentedController {
            controller.dismiss(animated: true)
            presentedController = nil
            isPresentedModally = false
            Window.presentedWindows.remove(id)
            return
        }
        #endif

        // Only show() on an app with several windows opens one.
        if let dismissWindow = WindowActions.shared.dismissWindow {
            dismissWindow(value: id)
        } else {
            let environment = EnvironmentValues()
            if environment.supportsMultipleWindows {
                environment.dismissWindow(value: id)
            }
        }
        Window.presentedWindows.remove(id)
    }

    internal static var windows = [ID: Window]()
    // Observable there, for a host to show what's open.
    internal static var presentedWindows: Set<ID> {
        get { WindowActions.shared.presented }
        set { WindowActions.shared.presented = newValue }
    }
}

/// A window's content, with the title and close button its presentation adds.
struct WindowContent: View {
    @State var window: Window

    var body: some View {
        @Bindable var window = window

        NavigationStack(path: $window.destinations) {
            FittedContent {
                SwiftUI.VStack(alignment: .leading, spacing: 8) {
                    ForEach(window.views.indices, id: \.self) { index in
                        window.views[index].asView
                    }
                }
            }
            .navigationTitle(window.title ?? "")
            .navigationDestination(for: Window.Destination.self) { destination in
                FittedContent {
                    destination.view.asView
                }
                .navigationTitle(destination.title ?? window.title ?? "")
            }
            // A real window gets a close from the OS; a modal has to bring one.
            #if canImport(UIKit)
            // Without a title the bar would stay hidden, and Close with it.
            .toolbarVisibility(window.closable && window.isPresentedModally ? .visible : .automatic, for: .navigationBar)
            .navigationBarTitleDisplayMode(window.title == nil ? .inline : .automatic)
            .toolbar {
                if window.closable && window.isPresentedModally {
                    // Pinned, it stays the trailing-most beside a view's own items.
                    if #available(iOS 27, visionOS 27, *) {
                        ToolbarItem(placement: .topBarPinnedTrailing) { closeButton }
                    } else {
                        ToolbarItem { closeButton }
                    }
                }
            }
            #endif
        }
        .environment(\.isInWindow, true)
        .windowSnapshots(for: window.id.id)
        // The system closed it, as a window of its own can always be.
        .onDisappear {
            Window.presentedWindows.remove(window.id)
        }
        #if canImport(UIKit)
        // Closing an iPad window ends its scene without the content
        // disappearing, which left Home showing it open.
        .background(SceneEndWatcher { [id = window.id] in
            Window.presentedWindows.remove(id)
        })
        #endif
    }

    private var closeButton: some View {
        SwiftUI.Button(role: .close) {
            window.close()
        }
    }
}

public extension EnvironmentValues {
    /// A window shows views as an app would, rather than in a notebook's cards.
    @Entry var isInWindow = false
}

public struct PythonWindowInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String?
}

/// A notebook, as what its windows and callbacks belong to.
public struct WindowOwner: Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// The id of Home, the app's main window group, which Python windows make way for.
public let homeWindowID = "home"

/// The window actions of the scenes on screen, for code outside a view. An action
/// made from a fresh environment opens nothing on iOS.
@MainActor
@Observable
public final class WindowActions {
    public static let shared = WindowActions()

    private var scenes: [UUID: (open: OpenWindowAction, dismiss: DismissWindowAction)] = [:]
    private var homes = Set<UUID>()
    var presented = Set<Window.ID>()

    /// The notebook running now, which windows and callbacks made now belong to.
    public var currentOwner: (@MainActor () -> WindowOwner?)?
    public var owner: WindowOwner? { currentOwner?() }

    /// Windows scripts opened that are shown, as windows of their own or as modals.
    public var openPythonWindows: Int { scriptWindows.count }

    /// The notebooks with a script's window shown, each once.
    public var windowOwners: [WindowOwner] {
        var seen = Set<String>()
        return scriptWindows.compactMap(\.owner).filter { seen.insert($0.id).inserted }
    }

    public func openPythonWindows(of owner: String) -> Int {
        scriptWindows.filter { $0.owner?.id == owner }.count
    }

    /// A notebook's shown windows, as a host lists them.
    public func pythonWindows(of owner: String) -> [PythonWindowInfo] {
        scriptWindows
            .filter { $0.owner?.id == owner }
            .map { PythonWindowInfo(id: $0.id.id, title: $0.title) }
            .sorted { $0.id < $1.id }
    }

    /// Brings a window of its own to the front; opening its id again focuses it.
    public func bringForward(_ id: String) {
        openWindow?(value: Window.ID(id: id))
    }

    private var scriptWindows: [Window] {
        presented.compactMap { Window.windows[$0] }.filter(\.isScript)
    }
    /// Whether this platform shows several windows, as an iPad and a Mac do.
    public private(set) var supportsMultipleWindows = false

    var openWindow: OpenWindowAction? { supportsMultipleWindows ? scenes.values.first?.open : nil }
    var dismissWindow: DismissWindowAction? { supportsMultipleWindows ? scenes.values.first?.dismiss : nil }
    public var isHomeOpen: Bool { !homes.isEmpty }

    fileprivate func appear(_ id: UUID, open: OpenWindowAction, dismiss: DismissWindowAction, isHome: Bool, supportsMultipleWindows: Bool) {
        scenes[id] = (open, dismiss)
        if isHome {
            // A second Home, as iPad's "+" opens: the new one, in front, stays.
            for other in homes where other != id {
                scenes[other]?.dismiss()
            }
            homes.insert(id)
        }
        self.supportsMultipleWindows = supportsMultipleWindows
    }

    fileprivate func disappear(_ id: UUID) {
        scenes[id] = nil
        homes.remove(id)
    }

    public func closePythonWindows(of owner: String? = nil) {
        for window in scriptWindows where owner == nil || window.owner?.id == owner {
            window.close()
        }
    }
}

private struct WindowActionsModifier: ViewModifier {
    let isHome: Bool

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                WindowActions.shared.appear(
                    id, open: openWindow, dismiss: dismissWindow,
                    isHome: isHome, supportsMultipleWindows: supportsMultipleWindows
                )
            }
            .onDisappear { WindowActions.shared.disappear(id) }
    }
}

public extension View {
    /// Lends this scene's window actions to ``WindowActions``; apply it to each scene's root.
    func windowActions(isHome: Bool = false) -> some View {
        modifier(WindowActionsModifier(isHome: isHome))
    }
}

#if canImport(UIKit)
/// Calls `ended` when the scene its view is in disconnects.
private struct SceneEndWatcher: UIViewRepresentable {
    let ended: @MainActor () -> Void

    func makeUIView(context: Context) -> WatcherView { WatcherView(ended: ended) }
    func updateUIView(_ view: WatcherView, context: Context) {}

    final class WatcherView: UIView {
        let ended: @MainActor () -> Void
        private var observer: (any NSObjectProtocol)?

        init(ended: @escaping @MainActor () -> Void) {
            self.ended = ended
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = NotificationCenter.default.addObserver(
                forName: UIScene.didDisconnectNotification, object: scene, queue: .main
            ) { [ended] _ in
                MainActor.assumeIsolated { ended() }
            }
        }

        isolated deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}
#endif
