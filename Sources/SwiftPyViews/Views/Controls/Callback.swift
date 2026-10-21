//
//  Callback.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// The coroutines the user started from a view, by a tap or a submit, while
/// they run: a host keeps the app going for them, as for a run.
@MainActor
@Observable
public final class ViewTasks {
    public static let shared = ViewTasks()

    @ObservationIgnored private var tasks: [UUID: AsyncTask] = [:]
    public private(set) var isRunning = false

    /// Stops every one, as when the time to run in the background is up.
    public func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
    }

    fileprivate func begin(_ task: AsyncTask) -> UUID {
        let id = UUID()
        tasks[id] = task
        isRunning = true
        return id
    }

    fileprivate func end(_ id: UUID) {
        tasks[id] = nil
        isRunning = !tasks.isEmpty
    }
}

extension PyObject {
    /// Calls a Python callback. A coroutine it returns runs to its end, which
    /// the returned task waits for; `isUserAction` counts it in ``ViewTasks``.
    @discardableResult
    func callback(isUserAction: Bool = false) -> Task<Void, Never>? {
        run(try? self(), isUserAction: isUserAction)
    }

    @discardableResult
    func callback(with value: some PythonConvertible) -> Task<Void, Never>? {
        run(try? self(value), isUserAction: false)
    }

    @MainActor
    private func run(_ result: PyObject?, isUserAction: Bool) -> Task<Void, Never>? {
        // An `async def` hands back a coroutine, not a task: it runs only
        // once it's driven.
        guard let result, Self.isAwaitable(result),
              let task = try? AsyncTask.from(result) else { return nil }
        // Not `on_appear`'s, which is often a loop that never ends.
        let id = isUserAction ? ViewTasks.shared.begin(task) : nil
        return Task { @MainActor in
            _ = try? await task.untilCompletes()
            if let id { ViewTasks.shared.end(id) }
        }
    }

    private static func isAwaitable(_ object: PyObject) -> Bool {
        if AsyncTask(object) != nil { return true }
        guard let inspect = py.module("inspect") else { return false }
        return (try? inspect.throwing.isawaitable(object)) ?? false
    }
}
