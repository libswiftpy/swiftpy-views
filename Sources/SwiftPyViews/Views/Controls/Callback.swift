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

/// A Python function a view calls back. It keeps where the run that gave it
/// sends its output, so what it prints, displays or raises lands there too:
/// in the notebook card that set it up.
@MainActor
public struct Callback: PythonConvertible {
    public let function: PyObject
    public let route: Interpreter.OutputRoute?

    public init(_ function: PyObject, route: Interpreter.OutputRoute? = Interpreter.outputRoute) {
        self.function = function
        self.route = route
    }

    public static var pyType: PyType { .object }

    // Converted inside the binding the run called, so its route is current.
    public static func fromPython(_ reference: PyRef) -> Callback {
        Callback(PyObject.fromPython(reference))
    }

    public func toPython() throws(PythonError) -> PyObject { function }

    /// Calls it. A coroutine it returns runs to its end, which the returned
    /// task waits for; `isUserAction` counts it in ``ViewTasks``.
    @discardableResult
    public func callback(isUserAction: Bool = false) -> Task<Void, Never>? {
        call(isUserAction: isUserAction) { () throws(PythonError) in try function() }
    }

    @discardableResult
    public func callback(with value: some PythonConvertible) -> Task<Void, Never>? {
        call(isUserAction: false) { () throws(PythonError) in try function(value) }
    }

    private func call(isUserAction: Bool, _ body: () throws(PythonError) -> PyObject) -> Task<Void, Never>? {
        Interpreter.withOutputRoute(route) {
            let result: PyObject
            do {
                result = try body()
            } catch {
                report(error)
                return nil
            }
            // An `async def` hands back a coroutine, not a task: it runs only
            // once it's driven, here, where it inherits the route.
            guard Self.isAwaitable(result), let task = try? AsyncTask.from(result) else { return nil }
            // Not `on_appear`'s, which is often a loop that never ends.
            let id = isUserAction ? ViewTasks.shared.begin(task) : nil
            return Task { @MainActor in
                do {
                    _ = try await task.untilCompletes()
                } catch {
                    report(error)
                }
                if let id { ViewTasks.shared.end(id) }
            }
        }
    }

    /// Its traceback, as output where the run's goes. A stop isn't an error.
    private func report(_ error: Error) {
        if let error = error as? PythonError,
           error.type.hasSuffix("CancelledError") || error.type == "KeyboardInterrupt" {
            return
        }
        var text = (error as? PythonError)?.traceback ?? "\(error)"
        if !text.hasSuffix("\n") { text += "\n" }
        if let route {
            route.write(text)
        } else {
            print(text, terminator: "")
        }
    }

    private static func isAwaitable(_ object: PyObject) -> Bool {
        if AsyncTask(object) != nil { return true }
        guard let inspect = py.module("inspect") else { return false }
        return (try? inspect.throwing.isawaitable(object)) ?? false
    }
}

extension PyObject {
    /// Calls it back from where the current run sends its output.
    @discardableResult
    func callback(isUserAction: Bool = false) -> Task<Void, Never>? {
        Callback(self).callback(isUserAction: isUserAction)
    }

    @discardableResult
    func callback(with value: some PythonConvertible) -> Task<Void, Never>? {
        Callback(self).callback(with: value)
    }
}
