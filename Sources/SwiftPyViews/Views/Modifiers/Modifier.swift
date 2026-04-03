//
//  Modifier.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-15.
//

import SwiftPy

protocol Modifier: Container {}

extension Modifier where Self: PythonBindable {
    func apply(_ content: PyAPI.Reference?) -> object? {
        let modifierRetained = retained
        self[.content] = content
        return modifierRetained.reference
    }
}
