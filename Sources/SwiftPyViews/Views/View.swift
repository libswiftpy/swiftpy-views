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
    static let View: PyType = PythonView.pyType
}

@Observable
@MainActor
@Scriptable("View")
final class PythonView {}
