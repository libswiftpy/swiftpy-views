//
//  StringLineBreaks.swift
//  swiftpy-views
//

public extension StringProtocol {
    /// Its line breaks: "\r\n" is one Character that isn't "\n", and the
    /// text view breaks at it, and at a lone "\r", too.
    var lineBreakCount: Int { count(where: \.isNewline) }
}
