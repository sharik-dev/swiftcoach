import Testing
@testable import swiftcoach

struct PromptBuilderTests {
    @Test func buildsCodeFocusedPrompt() async throws {
        let prompt = PromptBuilder.build(
            task: "Refactor this function",
            codeContext: "func greet(){print(\"hi\")}",
            languageHint: "French"
        )

        #expect(prompt.contains("Refactor this function"))
        #expect(prompt.contains("func greet(){print(\"hi\")}"))
        #expect(prompt.contains("Reply language: French."))
    }
}
