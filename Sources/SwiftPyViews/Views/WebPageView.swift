//
//  WebPageView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-09-22.
//

import SwiftPy
import SwiftUI
import WebKit

// Not named `WebView`: ours would shadow WebKit's, and `WebKit.WebView` is the
// deprecated AppKit class on macOS — the SwiftUI one lives in `_WebKit_SwiftUI`.
/// A view that displays a web page.
@Scriptable("_WebView", base: .View)
@MainActor
final class WebPageView {
    // The page owns the loaded content, not the view, so a container that
    // rebuilds the view re-attaches to it instead of loading again.
    internal let page = WebPage()

    /// Creates a view that loads a web page.
    ///
    /// url: The address of the page to load.
    init(url: String) throws {
        guard let parsed = URL(string: url), parsed.scheme != nil else {
            throw PythonError.ValueError("Invalid URL.")
        }

        page.load(parsed)
    }

    func body() -> AnyView {
        AnyView(WebPageViewContent(model: self))
    }
}

private struct WebPageViewContent: View {
    let model: WebPageView

    var body: some View {
        WebView(model.page)
            .fillsAvailableSpace()
    }
}
