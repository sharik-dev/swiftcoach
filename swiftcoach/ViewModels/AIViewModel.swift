import SwiftUI

@MainActor
final class AIViewModel: ObservableObject {
    @Published var output = ""
    @Published var isThinking = false
    @Published var lastError: String?
    @Published var remoteProviders: [RemoteProviderStatus] = []

    private var localService: LLMServiceProtocol?
    private let localServiceFactory: () -> LLMServiceProtocol
    private let remoteService: RemoteLLMService

    private var streamTask: Task<Void, Never>?
    private var modelLoadTask: Task<Void, Never>?
    private var activeModelID: String?

    init(
        llmService: LLMServiceProtocol? = nil,
        llmServiceFactory: @escaping () -> LLMServiceProtocol = { LocalLLMService() },
        remoteService: RemoteLLMService = RemoteLLMService()
    ) {
        self.localService = llmService
        self.localServiceFactory = llmServiceFactory
        self.remoteService = remoteService
    }

    func ensureModelLoaded(
        modelID: String,
        progressHandler: @escaping (Double) -> Void = { _ in },
        failureHandler: @escaping (String) -> Void = { _ in }
    ) {
        if activeModelID == modelID, localService?.isModelReady == true {
            progressHandler(1.0)
            return
        }

        if activeModelID != modelID || localService == nil {
            localService = localServiceFactory()
            activeModelID = modelID
        }

        guard let service = localService, !service.isModelReady else {
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

    func refreshRemoteProviders(baseURL: String, selectedProviderID: String?) async {
        do {
            remoteProviders = try await remoteService.fetchProviders(baseURL: baseURL)
            if let selectedProviderID,
               let provider = remoteProviders.first(where: { $0.id == selectedProviderID }),
               !provider.configured {
                lastError = "\(provider.displayName) is exposed by the backend but not configured on the server."
            } else {
                lastError = nil
            }
        } catch {
            remoteProviders = []
            lastError = "Backend unavailable: \(error.localizedDescription)"
        }
    }

    func generate(
        task: String,
        codeContext: String,
        provider: AppState.AIProvider,
        backendBaseURL: String,
        languageHint: String = "French"
    ) {
        streamTask?.cancel()
        output = ""
        lastError = nil
        isThinking = true

        let prompt = PromptBuilder.build(task: task, codeContext: codeContext, languageHint: languageHint)

        streamTask = Task {
            defer { isThinking = false }

            do {
                if provider.requiresLocalModel {
                    guard let service = localService, service.isModelReady else {
                        lastError = "The local model is not ready."
                        return
                    }

                    var accumulated = ""
                    let tokenStream = service.stream(systemPrompt: PromptBuilder.systemPrompt, prompt: prompt)

                    for await token in tokenStream {
                        guard !Task.isCancelled else { return }
                        accumulated += token
                        output = sanitize(accumulated)
                    }

                    if accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lastError = "No response produced by the local model."
                    }
                } else {
                    guard let remoteProviderID = provider.remoteProviderID else {
                        lastError = "Invalid backend provider selection."
                        return
                    }

                    let response = try await remoteService.generate(
                        baseURL: backendBaseURL,
                        provider: remoteProviderID,
                        systemPrompt: PromptBuilder.systemPrompt,
                        prompt: prompt
                    )
                    output = sanitize(response.output)

                    if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lastError = "No response produced by the backend provider."
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                lastError = error.localizedDescription
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
