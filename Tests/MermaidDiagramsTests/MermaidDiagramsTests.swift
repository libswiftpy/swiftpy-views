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
}
