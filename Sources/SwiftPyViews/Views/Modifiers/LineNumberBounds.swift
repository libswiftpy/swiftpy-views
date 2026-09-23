//
//  LineNumberBounds.swift
//  swiftpy-views
//

import SwiftUI

/// Where each line was laid out, published by a view that numbers its lines so
/// a host can anchor to one — an error marker beside the line that raised it.
public struct LineNumberBoundsKey: PreferenceKey {
    public static let defaultValue: [Int: Anchor<CGRect>] = [:]

    public static func reduce(
        value: inout [Int: Anchor<CGRect>],
        nextValue: () -> [Int: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { current, _ in current })
    }
}
