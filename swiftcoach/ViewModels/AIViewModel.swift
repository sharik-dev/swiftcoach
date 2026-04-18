import SwiftUI

@MainActor
final class AIViewModel: ObservableObject {
    @Published var output = ""
    @Published var isThinking = false
    @Published var lastError: String?
    @Published var remoteProviders: [RemoteProviderStatus] = []
    @Published var isTestingProvider = false
    @Published var providerTestResult: String?

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
            async let providersTask = remoteService.fetchProviders(baseURL: baseURL)
            async let healthTask = remoteService.fetchProviderHealth(baseURL: baseURL)
            let providers = try await providersTask
            let health = (try? await healthTask) ?? []
            remoteProviders = mergeProviders(providers: providers, health: health)
            if let selectedProviderID,
               let provider = remoteProviders.first(where: { $0.id == selectedProviderID }),
               !provider.isReady {
                lastError = "\(provider.displayName) is not ready: \(provider.statusLabel)."
            } else {
                lastError = nil
            }
        } catch {
            remoteProviders = []
            lastError = "Backend unavailable: \(error.localizedDescription)"
        }
    }

    func testSelectedProvider(provider: AppState.AIProvider, backendBaseURL: String) async {
        guard let remoteProviderID = provider.remoteProviderID else {
            providerTestResult = "Local MLX does not use the backend test."
            return
        }

        isTestingProvider = true
        providerTestResult = nil
        defer { isTestingProvider = false }

        do {
            let response = try await remoteService.generate(
                baseURL: backendBaseURL,
                provider: remoteProviderID,
                systemPrompt: "Tu réponds en un seul mot.",
                prompt: "Réponds uniquement par OK.",
                temperature: 0,
                maxTokens: 8
            )
            let sanitized = sanitize(response.output)
            providerTestResult = sanitized.isEmpty
                ? "\(provider.displayName) responded with an empty message."
                : "\(provider.displayName): \(sanitized)"
            await refreshRemoteProviders(baseURL: backendBaseURL, selectedProviderID: remoteProviderID)
        } catch {
            providerTestResult = error.localizedDescription
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

        streamTask = Task {
            defer { isThinking = false }

            do {
                output = try await requestResponse(
                    task: task,
                    codeContext: codeContext,
                    provider: provider,
                    backendBaseURL: backendBaseURL,
                    languageHint: languageHint
                )
            } catch is CancellationError {
                return
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func requestResponse(
        task: String,
        codeContext: String,
        provider: AppState.AIProvider,
        backendBaseURL: String,
        languageHint: String = "French"
    ) async throws -> String {
        let prompt = PromptBuilder.build(task: task, codeContext: codeContext, languageHint: languageHint)

        if provider.requiresLocalModel {
            guard let service = localService, service.isModelReady else {
                throw NSError(domain: "AIViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "The local model is not ready."])
            }

            var accumulated = ""
            let tokenStream = service.stream(systemPrompt: PromptBuilder.systemPrompt, prompt: prompt)

            for await token in tokenStream {
                guard !Task.isCancelled else { throw CancellationError() }
                accumulated += token
            }

            let sanitized = sanitize(accumulated)
            if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw NSError(domain: "AIViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response produced by the local model."])
            }
            return sanitized
        }

        guard let remoteProviderID = provider.remoteProviderID else {
            throw NSError(domain: "AIViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid backend provider selection."])
        }

        let response = try await remoteService.generate(
            baseURL: backendBaseURL,
            provider: remoteProviderID,
            systemPrompt: PromptBuilder.systemPrompt,
            prompt: prompt
        )
        let sanitized = sanitize(response.output)
        if sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(domain: "AIViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "No response produced by the backend provider."])
        }
        return sanitized
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

    private func mergeProviders(providers: [RemoteProviderStatus], health: [RemoteProviderStatus]) -> [RemoteProviderStatus] {
        let healthByID = Dictionary(uniqueKeysWithValues: health.map { ($0.id, $0) })

        return providers.map { provider in
            guard let health = healthByID[provider.id] else {
                return provider
            }

            return RemoteProviderStatus(
                id: provider.id,
                model: provider.model,
                configured: provider.configured,
                reachable: health.reachable,
                status: health.status,
                transport: health.transport
            )
        }
    }
}
