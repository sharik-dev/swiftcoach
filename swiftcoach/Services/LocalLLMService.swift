import Foundation
import LocalLLMClient
import LocalLLMClientMLX

final class LocalLLMService: LLMServiceProtocol {
    private var client: AnyLLMClient?
    private(set) var isModelReady = false

    func loadModel(
        modelID: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let model = LLMSession.DownloadModel.mlx(id: modelID)

        if model.isDownloaded {
            progressHandler(1.0)
        } else {
            try await model.downloadModel { progress in
                progressHandler(progress)
            }
        }

        client = try await AnyLLMClient(LocalLLMClient.mlx(url: model.modelPath))
        isModelReady = true
    }

    func stream(systemPrompt: String, prompt: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            guard let client else {
                continuation.finish()
                return
            }

            let input = LLMInput.chat([
                .system(systemPrompt),
                .user(prompt)
            ])

            Task {
                do {
                    let tokenStream = try await client.textStream(from: input)
                    for try await token in tokenStream {
                        continuation.yield(token)
                    }
                } catch {
                    // The caller handles an incomplete stream.
                }

                continuation.finish()
            }
        }
    }
}
