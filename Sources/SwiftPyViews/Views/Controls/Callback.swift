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

    @ObservationIgnored private var tasks: [UUID: (task: AsyncTask, owner: String?)] = [:]
    public private(set) var isRunning = false
    /// Tasks running per owner, a notebook's id.
    public private(set) var running: [String: Int] = [:]
    /// The last line of what a view's callback last raised, per owner, until its next tap.
    public private(set) var failures: [String: String] = [:]

    /// Stops every one, as when the time to run in the background is up.
    public func cancelAll() {
        for entry in tasks.values {
            entry.task.cancel()
        }
        failures = [:]
    }

    public func cancel(owner: String) {
        for entry in tasks.values where entry.owner == owner {
            entry.task.cancel()
        }
        failures[owner] = nil
    }

    public func clearFailure(owner: String) {
        failures[owner] = nil
    }

    fileprivate func fail(_ line: String, owner: String?) {
        guard let owner else { return }
        failures[owner] = line
    }

    fileprivate func begin(_ task: AsyncTask, owner: String?) -> UUID {
        let id = UUID()
        tasks[id] = (task, owner)
        isRunning = true
        if let owner {
            running[owner, default: 0] += 1
            failures[owner] = nil
        }
        return id
    }

    fileprivate func end(_ id: UUID) {
        if let owner = tasks.removeValue(forKey: id)?.owner {
            running[owner] = (running[owner] ?? 1) > 1 ? running[owner]! - 1 : nil
        }
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
    /// The notebook that set it up, whose work it is.
    public let owner: String?

    public init(
        _ function: PyObject,
        route: Interpreter.OutputRoute? = Interpreter.outputRoute,
        owner: String? = WindowActions.shared.owner?.id
    ) {
        self.function = function
        self.owner = owner
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
            let id = isUserAction ? ViewTasks.shared.begin(task, owner: owner) : nil
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
        // Without the colors the traceback is printed in.
        let plain = text.replacing(/\u{1B}\[[0-9;]*m/, with: "")
        let lastLine = plain.split(separator: "\n").last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        ViewTasks.shared.fail(lastLine.map(String.init) ?? plain, owner: owner)
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
