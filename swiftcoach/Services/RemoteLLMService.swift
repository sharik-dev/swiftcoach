import Foundation

struct RemoteProviderStatus: Codable, Identifiable {
    let id: String
    let model: String
    let configured: Bool

    var displayName: String {
        id.capitalized
    }
}

private struct ProvidersResponse: Codable {
    let providers: [RemoteProviderStatus]
}

private struct ChatRequest: Codable {
    let provider: String
    let message: String
    let system: String
}

struct ChatResponse: Codable {
    let provider: String
    let model: String
    let output: String
}

private struct BackendErrorResponse: Codable {
    let error: String
}

final class RemoteLLMService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProviders(baseURL: String) async throws -> [RemoteProviderStatus] {
        let url = try makeURL(baseURL: baseURL, path: "/providers")
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ProvidersResponse.self, from: data).providers
    }

    func generate(baseURL: String, provider: String, systemPrompt: String, prompt: String) async throws -> ChatResponse {
        let url = try makeURL(baseURL: baseURL, path: "/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                provider: provider,
                message: prompt,
                system: systemPrompt
            )
        )

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }

    private func makeURL(baseURL: String, path: String) throws -> URL {
        let trimmedBaseURL = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: trimmedBaseURL + path) else {
            throw URLError(.badURL)
        }

        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw NSError(
                    domain: "RemoteLLMService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: backendError.error]
                )
            }

            throw NSError(
                domain: "RemoteLLMService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)]
            )
        }
    }
}
