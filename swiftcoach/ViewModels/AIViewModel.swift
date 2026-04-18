import SwiftUI

@MainActor
final class AIViewModel: ObservableObject {
    @Published var output = ""
    @Published var isThinking = false
    @Published var lastError: String?

    var llmService: LLMServiceProtocol?

    private var streamTask: Task<Void, Never>?
    private var modelLoadTask: Task<Void, Never>?
    private var activeModelID: String?

    func ensureModelLoaded(
        modelID: String,
        progressHandler: @escaping (Double) -> Void = { _ in },
        failureHandler: @escaping (String) -> Void = { _ in }
    ) {
        if activeModelID == modelID, llmService?.isModelReady == true {
            progressHandler(1.0)
            return
        }

        if activeModelID != modelID || llmService == nil {
            llmService = LocalLLMService()
            activeModelID = modelID
        }

        guard let service = llmService, !service.isModelReady else {
            progressHandler(1.0)
            return
        }

        modelLoadTask?.cancel()
        modelLoadTask = Task {
            do {
                try await service.loadModel(modelID: modelID, progressHandler: progressHandler)
            } catch is CancellationError {
            } catch {
                failureHandler(error.localizedDescription)
            }
        }
    }

    func generate(task: String, codeContext: String, languageHint: String = "French") {
        guard let service = llmService, service.isModelReady else { return }

        streamTask?.cancel()
        output = ""
        lastError = nil
        isThinking = true

        let prompt = PromptBuilder.build(task: task, codeContext: codeContext, languageHint: languageHint)
        let tokenStream = service.stream(systemPrompt: PromptBuilder.systemPrompt, prompt: prompt)

        streamTask = Task {
            var accumulated = ""

            for await token in tokenStream {
                guard !Task.isCancelled else { break }
                accumulated += token
                output = sanitize(accumulated)
            }

            isThinking = false

            if accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lastError = "No response produced by the local model."
            }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        isThinking = false
    }

    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
