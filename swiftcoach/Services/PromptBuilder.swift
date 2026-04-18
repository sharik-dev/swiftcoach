import Foundation

enum PromptBuilder {
    static let systemPrompt = """
    You are Swift Coach, a concise local coding assistant running on-device.

    Priorities:
    1. Produce technically correct code-first answers.
    2. Prefer practical fixes over theory.
    3. Keep responses compact and directly usable.

    Rules:
    - If the user asks for code, output the code first.
    - If you change existing code, preserve the user's architecture unless it is clearly broken.
    - Mention assumptions briefly when they materially affect correctness.
    - Avoid long introductions and avoid markdown tables.
    - When the request is ambiguous, choose the safest reasonable interpretation and continue.
    - If the answer includes Swift, prefer modern Swift 5.10+ and SwiftUI/iOS 17 friendly patterns.
    """

    static func build(
        task: String,
        codeContext: String,
        languageHint: String
    ) -> String {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = codeContext.trimmingCharacters(in: .whitespacesAndNewlines)

        let safeTask = trimmedTask.isEmpty ? "Explain the current code and suggest the next safe step." : trimmedTask
        let safeContext = trimmedContext.isEmpty ? "No code context provided." : trimmedContext

        return """
        Reply language: \(languageHint).

        User request:
        \(safeTask)

        Code context:
        \(safeContext)

        Output format:
        - Start with the direct answer or code.
        - If needed, add a short \"Why\" section.
        - If you provide code, keep comments minimal and useful.
        """
    }
}
