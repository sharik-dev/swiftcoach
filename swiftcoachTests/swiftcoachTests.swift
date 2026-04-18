import Foundation
import Testing
@testable import swiftcoach

@MainActor
struct swiftcoachTests {
    @Test func promptBuilderUsesSafeFallbacks() {
        let prompt = PromptBuilder.build(
            task: "   ",
            codeContext: "\n",
            languageHint: "French"
        )

        #expect(prompt.contains("Explain the current code and suggest the next safe step."))
        #expect(prompt.contains("No code context provided."))
        #expect(prompt.contains("Reply language: French."))
    }

    @Test func ensureModelLoadedReportsReadyImmediatelyWhenServiceIsAlreadyConnected() {
        let service = MockLLMService()
        service.isModelReady = true
        let viewModel = AIViewModel(llmService: service)
        var reportedProgress: [Double] = []

        viewModel.ensureModelLoaded(
            modelID: "existing-model",
            progressHandler: { reportedProgress.append($0) }
        )

        #expect(reportedProgress == [1.0])
        #expect(service.loadModelCallCount == 0)
    }

    @Test func ensureModelLoadedUsesFactoryAndPropagatesConnectionFailure() async throws {
        let service = MockLLMService()
        service.loadError = URLError(.notConnectedToInternet)
        var factoryCallCount = 0
        let viewModel = AIViewModel(llmServiceFactory: {
            factoryCallCount += 1
            return service
        })

        var receivedFailure: String?
        viewModel.ensureModelLoaded(
            modelID: "backend-model",
            failureHandler: { receivedFailure = $0 }
        )

        try await Task.sleep(for: .milliseconds(50))

        #expect(factoryCallCount == 1)
        #expect(service.loadModelCallCount == 1)
        #expect(receivedFailure?.contains("internet") == true || receivedFailure?.contains("Internet") == true)
    }

    @Test func generateStreamsResponseAndSanitizesBackendMarkers() async throws {
        let service = MockLLMService()
        service.isModelReady = true
        service.streamTokens = ["Bonjour", "\r\n", "<|im_end|>", "Swift", "<|endoftext|>"]
        let viewModel = AIViewModel(llmService: service)

        viewModel.generate(task: "Explique", codeContext: "let value = 1")
        try await Task.sleep(for: .milliseconds(80))

        #expect(viewModel.output == "Bonjour\nSwift")
        #expect(viewModel.isThinking == false)
        #expect(viewModel.lastError == nil)
        #expect(service.lastSystemPrompt == PromptBuilder.systemPrompt)
        #expect(service.lastPrompt?.contains("User request:") == true)
    }

    @Test func generateSetsErrorWhenBackendReturnsEmptyStream() async throws {
        let service = MockLLMService()
        service.isModelReady = true
        service.streamTokens = []
        let viewModel = AIViewModel(llmService: service)

        viewModel.generate(task: "Test", codeContext: "")
        try await Task.sleep(for: .milliseconds(30))

        #expect(viewModel.output.isEmpty)
        #expect(viewModel.isThinking == false)
        #expect(viewModel.lastError == "No response produced by the local model.")
    }

    @Test func cancelStreamStopsThinkingDuringSlowBackendStream() async throws {
        let service = MockLLMService()
        service.isModelReady = true
        service.streamTokens = ["A", "B", "C"]
        service.tokenDelayNanoseconds = 80_000_000
        let viewModel = AIViewModel(llmService: service)

        viewModel.generate(task: "Long task", codeContext: "context")
        try await Task.sleep(for: .milliseconds(20))
        viewModel.cancelStream()
        try await Task.sleep(for: .milliseconds(30))

        #expect(viewModel.isThinking == false)
    }
}

private final class MockLLMService: LLMServiceProtocol {
    var isModelReady = false
    var loadError: Error?
    var streamTokens: [String] = []
    var tokenDelayNanoseconds: UInt64 = 0

    private(set) var loadModelCallCount = 0
    private(set) var lastLoadedModelID: String?
    private(set) var lastSystemPrompt: String?
    private(set) var lastPrompt: String?

    func loadModel(
        modelID: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        loadModelCallCount += 1
        lastLoadedModelID = modelID

        if let loadError {
            throw loadError
        }

        progressHandler(0.25)
        progressHandler(1.0)
        isModelReady = true
    }

    func stream(systemPrompt: String, prompt: String) -> AsyncStream<String> {
        lastSystemPrompt = systemPrompt
        lastPrompt = prompt

        let tokens = streamTokens
        let delay = tokenDelayNanoseconds

        return AsyncStream { continuation in
            Task {
                for token in tokens {
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: delay)
                    }

                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }

                    continuation.yield(token)
                }

                continuation.finish()
            }
        }
    }
}
