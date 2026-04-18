import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let role: Role
        var content: String

        enum Role { case user, assistant }
    }

    @Published var messages: [Message] = []
    @Published var isStreaming = false

    private let service = LocalLLMService()
    private var streamTask: Task<Void, Never>?

    var isModelReady: Bool { service.isModelReady }

    func loadModel(
        modelID: String,
        onProgress: @escaping (Double) -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        Task {
            do {
                try await service.loadModel(modelID: modelID, progressHandler: onProgress)
            } catch {
                onFailure(error.localizedDescription)
            }
        }
    }

    func send(text: String, codeContext: String = "") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming, service.isModelReady else { return }

        let prompt = codeContext.isEmpty
            ? trimmed
            : "\(trimmed)\n\n```swift\n\(codeContext)\n```"

        messages.append(Message(role: .user, content: trimmed))
        messages.append(Message(role: .assistant, content: ""))
        let lastIndex = messages.count - 1

        isStreaming = true
        streamTask?.cancel()
        streamTask = Task {
            defer { isStreaming = false }
            let system = """
            Tu es un expert Swift et SwiftUI. \
            Réponds toujours en français, de manière concise et précise. \
            Pour les extraits de code, utilise des blocs ```swift.
            """
            let stream = service.stream(systemPrompt: system, prompt: prompt)
            for await token in stream {
                guard !Task.isCancelled else { break }
                messages[lastIndex].content += token
            }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        isStreaming = false
    }
}
