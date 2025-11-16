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

    var content: object? {
        get { self[.content] }
        set { self[.content] = newValue }
    }

    internal let id: ID

    init(arguments: PyArguments) throws {
        try arguments.expectedArgCount(2)
        // Create an empty window with the ID.
        if let id = String(arguments[1]) {
            self.id = ID(id: id)
            return
        }

        guard let content = arguments[1] else {
            throw PythonError.ValueError("Expected a view at position 1")
        }
        id = ID(id: String(Int(bitPattern: content)))
        arguments[Slot.content] = arguments[1]
        
        Window.windows[id] = self
    }

    func open() throws {
        guard let view = content?.anyView else {
            throw PythonError.RuntimeError("Content is not view representable.")
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

        let vc = UIHostingController(rootView: view)

        let id = id
        topController?.present(vc, animated: true) {
            Window.presentedWindows.remove(id)
        }
        Window.presentedWindows.insert(id)

        #endif
    }

    internal static var windows = [ID: Window]()
    internal static var presentedWindows = Set<ID>()
}

extension Window: HasSlots {
    enum Slot: Int32, CaseIterable {
        case content
    }
}
