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

    internal let id: ID

    #if canImport(UIKit)
    // Weak: the presented controller's root view holds the window.
    @ObservationIgnored private weak var presentedController: UIViewController?
    #endif

    /// Creates a window to present views in.
    ///
    /// title: Text the navigation stack shows. Defaults to None, which leaves the window untitled.
    /// closable: Whether the window shows a close button. Defaults to True.
    /// sheet: Presents the window as a sheet instead of a fullscreen cover. Defaults to False.
    init(title: String? = nil, closable: Bool = true, sheet: Bool = false) {
        self.title = title
        self.closable = closable
        self.sheet = sheet
        id = ID(id: UUID().uuidString)
        Window.windows[id] = self
    }

    /// Appends a view to the window's content.
    ///
    /// view: A view, or a string to show as text.
    func add(_ view: PyObject) {
        views.append(view)
    }

    /// Presents the window.
    func show() {
        #if os(macOS) || os(visionOS)
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

        topController?.present(controller, animated: true)
        presentedController = controller
        Window.presentedWindows.insert(id)
        #endif
    }

    /// Dismisses the window.
    func close() {
        #if canImport(UIKit)
        if let controller = presentedController {
            controller.dismiss(animated: true)
            presentedController = nil
            Window.presentedWindows.remove(id)
            return
        }
        #endif

        EnvironmentValues().dismissWindow(value: id)
        Window.presentedWindows.remove(id)
    }

    internal static var windows = [ID: Window]()
    internal static var presentedWindows = Set<ID>()
}

/// A window's content, with the title and close button its presentation adds.
struct WindowContent: View {
    @State var window: Window

    var body: some View {
        NavigationStack {
            SwiftUI.ScrollView {
                SwiftUI.VStack(alignment: .leading, spacing: 8) {
                    ForEach(window.views.indices, id: \.self) { index in
                        window.views[index].asView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            // Content that already fits shouldn't rubber-band.
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(window.title ?? "")
            .toolbar {
                if window.closable {
                    SwiftUI.Button(role: .close) {
                        window.close()
                    }
                }
            }
        }
    }
}
