//
//  MermaidDiagrams.swift
//  swiftpy-views
//

import SwiftUI
import WebKit
import SwiftPyViews

public enum MermaidDiagrams {
    /// Draws markdown's ` ```mermaid ` blocks as diagrams.
    @MainActor
    public static func initialize() {
        MarkdownCodeBlockRenderers.renderers["mermaid"] = { AnyView(MermaidDiagram(code: $0)) }
    }

    /// Mermaid 11.17.2, bundled as `NSData.compressed(using: .lzma)` (3.6 MB to 0.75 MB)
    /// and decompressed once, on first use.
    static let script = Task.detached(priority: .userInitiated) { () -> String? in
        guard let url = Bundle.module.url(forResource: "mermaid.min.js", withExtension: "lzma"),
              let data = try? NSData(contentsOf: url).decompressed(using: .lzma) else { return nil }
        return String(decoding: data as Data, as: UTF8.self)
    }
}

/// A diagram drawn by Mermaid, falling back to its code when it doesn't parse.
struct MermaidDiagram: View {
    let code: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var page: WebPage?
    /// Unstructured, so a redraw cancelled by streaming text doesn't cancel the load
    /// and leave a page without Mermaid.
    @State private var loading: Task<WebPage, Error>?
    @State private var size: CGSize?
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                VStack(alignment: .leading, spacing: 6) {
                    Text(code)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary, in: .rect(cornerRadius: 16))
                        .textSelection(.enabled)
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let page, let size {
                WebView(page)
                    .webViewContentBackground(.hidden)
                    // Scrolling the note passes through it.
                    .allowsHitTesting(false)
                    .aspectRatio(size, contentMode: .fit)
                    .frame(maxWidth: size.width)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Diagram")
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .task(id: [code, colorScheme == .dark ? "dark" : "default"]) {
            await render(theme: colorScheme == .dark ? "dark" : "default")
        }
    }

    private func render(theme: String) async {
        do {
            // Text still streaming in redraws once it rests.
            if size != nil || error != nil {
                try await Task.sleep(for: .milliseconds(250))
            }
            let page: WebPage
            if let existing = self.page {
                page = existing
            } else {
                let loading = self.loading ?? Task { try await MermaidPage.make() }
                self.loading = loading
                do {
                    page = try await loading.value
                } catch {
                    // A later redraw tries again.
                    self.loading = nil
                    throw error
                }
                self.page = page
            }
            try Task.checkCancellation()
            switch try await MermaidPage.render(code, theme: theme, in: page) {
            case let .success(size):
                self.size = size
                error = nil
            case let .failure(failure):
                error = failure.message
            }
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A page with Mermaid loaded, under a CSP that allows no scripts or loads of its own.
enum MermaidPage {
    struct Failure: Error {
        let message: String
    }

    @MainActor
    static func make() async throws -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        // A user script isn't subject to the page's CSP, which blocks any script
        // a diagram might carry.
        guard let script = await MermaidDiagrams.script.value else {
            throw Failure(message: "Mermaid isn't available.")
        }
        configuration.userContentController.addUserScript(
            WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        let page = WebPage(configuration: configuration)
        for try await _ in page.load(html: html) {}
        // A cancelled load ends without throwing.
        try Task.checkCancellation()
        guard try await page.callJavaScript("return typeof mermaid === 'object'") as? Bool == true else {
            throw Failure(message: "Mermaid didn't load.")
        }
        return page
    }

    /// The diagram's natural size, or Mermaid's message for code that doesn't parse.
    @MainActor
    static func render(_ code: String, theme: String, in page: WebPage) async throws -> Result<CGSize, Failure> {
        let result: [String: Any]?
        do {
            result = try await page.callJavaScript(render, arguments: ["source": code, "theme": theme]) as? [String: Any]
        } catch let error as NSError {
            // Its own message, rather than "A JavaScript exception occurred".
            let message = error.userInfo["WKJavaScriptExceptionMessage"] as? String
            return .failure(Failure(message: message ?? error.localizedDescription))
        }
        if let width = result?["width"] as? Double, let height = result?["height"] as? Double, width > 0, height > 0 {
            return .success(CGSize(width: width, height: height))
        }
        let message = (result?["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failure(Failure(message: message ?? "The diagram couldn't be drawn."))
    }

    static let html = """
    <!doctype html><html><head><meta charset="utf-8">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>html,body{margin:0;background:transparent}#diagram svg{display:block;width:100%;height:auto;max-width:none!important}</style>
    </head><body><div id="diagram"></div></body></html>
    """

    private static let render = """
    try {
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        theme,
        fontFamily: '-apple-system, system-ui, sans-serif',
      });
      const { svg } = await mermaid.render('mermaid-diagram', source);
      const diagram = document.getElementById('diagram');
      diagram.innerHTML = svg;
      const box = diagram.querySelector('svg').viewBox.baseVal;
      return { width: box.width, height: box.height };
    } catch (error) {
      return { error: String(error && error.message || error) };
    }
    """
}
