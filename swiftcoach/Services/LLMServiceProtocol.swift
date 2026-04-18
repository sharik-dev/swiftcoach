import Foundation

protocol LLMServiceProtocol: AnyObject {
    var isModelReady: Bool { get }

    func loadModel(
        modelID: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws

    func stream(systemPrompt: String, prompt: String) -> AsyncStream<String>
}
