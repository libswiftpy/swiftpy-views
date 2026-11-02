//
//  Group.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-06-05.
//

import SwiftPy
import SwiftUI

/// Views kept together, laid out by the container they're in, and a
/// container's `content`. Changing it updates what's on screen.
@Scriptable(base: .View)
@MainActor
@Observable
final class Group {
    internal var objects: [PyObject]

    /// Creates a group.
    ///
    /// content: Views, or strings to show as text.
    init(content: Unpack) {
        objects = content.values
    }

    internal init(objects: [PyObject]) {
        self.objects = objects
    }

    /// Appends a view, or a string to show as text.
    func append(_ view: PyObject) {
        objects.append(view)
    }

    /// Inserts a view before `index`.
    func insert(_ index: Int, _ view: PyObject) {
        let count = objects.count
        let position = index < 0 ? max(count + index, 0) : min(index, count)
        objects.insert(view, at: position)
    }

    /// Removes the first occurrence of a view, or of an equal string.
    func remove(_ view: PyObject) throws {
        let text = String(view)
        guard let index = objects.firstIndex(where: { object in
            object.reference == view.reference || (text != nil && String(object) == text)
        }) else {
            throw PythonError(type: "ValueError", value: "Group.remove(x): x not in group")
        }
        objects.remove(at: index)
    }

    /// Removes every view.
    func clear() {
        objects.removeAll()
    }

    func __getitem__(_ index: Int) throws -> PyObject {
        objects[try position(of: index)]
    }

    func __setitem__(_ index: Int, _ view: PyObject) throws {
        objects[try position(of: index)] = view
    }

    func __delitem__(_ index: Int) throws {
        objects.remove(at: try position(of: index))
    }

    func __len__() -> Int {
        objects.count
    }

    func body() -> AnyView {
        AnyView(GroupContent(model: self))
    }

    /// Python's indexing, negative from the end; the IndexError past either
    /// end also ends a `for` loop.
    private func position(of index: Int) throws -> Int {
        let position = index < 0 ? objects.count + index : index
        guard objects.indices.contains(position) else {
            throw PythonError(type: "IndexError", value: "group index out of range")
        }
        return position
    }

    /// Each view by its object, and which occurrence of it, so removing one
    /// keeps the state of the others.
    internal var identified: [(id: ItemID, object: PyObject)] {
        var seen: [Int: Int] = [:]
        return objects.map { object in
            let address = Int(bitPattern: UnsafeRawPointer(object.reference))
            let occurrence = seen[address, default: 0]
            seen[address] = occurrence + 1
            return (ItemID(address: address, occurrence: occurrence), object)
        }
    }

    internal struct ItemID: Hashable {
        let address: Int
        let occurrence: Int
    }
}

private struct GroupContent: View {
    let model: Group

    var body: some View {
        ForEach(model.identified, id: \.id) { item in
            item.object.asView
        }
    }
}
