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

@MainActor
@Observable
@Scriptable
class Window: Identifiable {
    struct ID: Codable, Hashable {
        let id: String
    }

    typealias object = PyAPI.Reference

    var isFullscreen: Bool = false
    var content: AnyView?
    
    internal var presentationContext: Any?
    internal let id: ID
    
    init(id: String) {
        self.id = ID(id: id)
        Window.windows[self.id] = self
    }

    init(view: PyObject) {
        id = ID(id: String(Int(bitPattern: view.reference)))
        self.content = view.asView
        Window.windows[id] = self
    }

    func open() throws {
        guard let content else {
            throw PythonError.AssertionError("No view to present.")
        }

        let defaults = EnvironmentValues()
        if defaults.supportsMultipleWindows {
            defaults.openWindow(value: id)
            Window.presentedWindows.insert(id)
            return
        }
        
        #if canImport(UIKit)
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .compactMap(\.keyWindow).first
        
        var topController = window?.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }

        let navigation = NavigationStack { content }
        let vc = UIHostingController(rootView: navigation)
        vc.modalPresentationStyle = isFullscreen ? .fullScreen : .pageSheet
        
        let id = id
        topController?.present(vc, animated: true) {
            Window.presentedWindows.remove(id)
        }
        Window.presentedWindows.insert(id)
        presentationContext = vc

        #endif
    }
    
    func close() {
        #if canImport(UIKit)
        if let context = presentationContext as? UIViewController {
            context.dismiss(animated: true)
            Window.presentedWindows.remove(id)
            return
        }
        #endif

        let environment = EnvironmentValues()
        environment.dismissWindow(value: id)
        Window.presentedWindows.remove(id)
    }

    internal static var windows = [ID: Window]()
    internal static var presentedWindows = Set<ID>()
}
