import Testing
import WebKit
@testable import MermaidDiagrams

@MainActor
struct MermaidDiagramsTests {
    private func render(_ code: String) async throws -> Result<CGSize, MermaidPage.Failure> {
        let page = try await MermaidPage.make()
        return try await MermaidPage.render(code, theme: "default", in: page)
    }

    @Test func decompressesMermaid() async {
        let script = await MermaidDiagrams.script.value
        #expect(script?.contains("globalThis[\"mermaid\"]") == true)
    }

    @Test func drawsAFlowchart() async throws {
        let size = try await render("flowchart TD\n  A[Start] --> B{Is it?}\n  B -->|Yes| C[OK]").get()
        #expect(size.width > 50 && size.height > 50)
    }

    @Test func drawsASequenceDiagramWithAngleBrackets() async throws {
        let size = try await render("sequenceDiagram\n  Alice->>Bob: Hi <b>there</b>\n  Bob-->>Alice: Hello").get()
        #expect(size.height > 50)
    }

    @Test func reportsASyntaxError() async throws {
        let result = try await render("flowchart TD\n  A --> --> ")
        guard case let .failure(failure) = result else {
            Issue.record("Expected an error, got \(result)")
            return
        }
        #expect(!failure.message.isEmpty)
    }

    // Streaming text cancels redraws mid-load, which used to keep a page without Mermaid.
    @Test func aCancelledLoadNeverGivesAPageWithoutMermaid() async throws {
        for delay in [0, 5, 20, 50] {
            let task = Task { try await MermaidPage.make() }
            try await Task.sleep(for: .milliseconds(delay))
            task.cancel()
            if let page = try? await task.value {
                #expect(try await page.callJavaScript("return typeof mermaid") as? String == "object")
            }
        }
    }

    @Test func redrawsOnTheSamePage() async throws {
        let page = try await MermaidPage.make()
        _ = try await MermaidPage.render("flowchart TD\n  A --> ", theme: "dark", in: page)
        let size = try await MermaidPage.render("flowchart TD\n  A --> B", theme: "dark", in: page).get()
        #expect(size.height > 20)
    }
}
