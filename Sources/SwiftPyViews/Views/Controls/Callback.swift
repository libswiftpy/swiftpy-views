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
        guard let task = AsyncTask(result) else { return nil }
        return Task { _ = try? await task.untilCompletes() }
    }
}
