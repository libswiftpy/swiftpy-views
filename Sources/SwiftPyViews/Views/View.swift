//
//  View.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-01.
//

import SwiftPy
import SwiftUI

@MainActor
public extension PyType {
    static let View: PyType = AnyView.pyType
}

protocol PythonView: View, PythonConvertible {}

extension PythonConvertible where Self: View {
    static var pyType: PyType { AnyView.pyType }

    static func fromPython(_ reference: PyRef) -> any View {
        reference.view ?? AnyView(erasing: EmptyView())
    }

    func toPython(_ reference: PyRef) {
        AnyView(erasing: self).toPython(reference)
    }
}

@Observable
@MainActor
@Scriptable("View")
final class BaseView {}
