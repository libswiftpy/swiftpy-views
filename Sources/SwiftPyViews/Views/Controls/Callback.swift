//
//  Callback.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

extension PyObject {
    /// Calls a Python callback. A coroutine it returns runs to its end, which
    /// the returned task waits for.
    @discardableResult
    func callback() -> Task<Void, Never>? {
        run(try? self())
    }

    @discardableResult
    func callback(with value: some PythonConvertible) -> Task<Void, Never>? {
        run(try? self(value))
    }

    private func run(_ result: PyObject?) -> Task<Void, Never>? {
        // An `async def` hands back a coroutine, not a task: it runs only
        // once it's driven.
        guard let result, Self.isAwaitable(result),
              let task = try? AsyncTask.from(result) else { return nil }
        return Task { _ = try? await task.untilCompletes() }
    }

    private static func isAwaitable(_ object: PyObject) -> Bool {
        if AsyncTask(object) != nil { return true }
        guard let inspect = py.module("inspect") else { return false }
        return (try? inspect.throwing.isawaitable(object)) ?? false
    }
}
