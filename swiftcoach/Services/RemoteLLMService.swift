import Foundation

final class RemoteLLMService {
    enum ServiceError: LocalizedError, Equatable {
        case invalidBaseURL(String)
        case invalidResponse
        case backend(statusCode: Int, message: String)
        case http(statusCode: Int, message: String)
        case networkUnavailable
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL(let value):
                return "Invalid backend URL: \(value)"
            case .invalidResponse:
                return "The backend returned an invalid response."
            case .backend(_, let message):
                return message
            case .http(_, let message):
                return message
            case .networkUnavailable:
                return "The backend is unavailable. Check the server and the URL."
            case .transport(let message):
                return message
            }
        }
    }

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProviders(baseURL: String) async throws -> [RemoteProviderStatus] {
        let response: ProvidersResponse = try await request(
            baseURL: baseURL,
            path: "/providers",
            method: "GET",
            body: nil
        )
        return response.providers
    }

    func generate(baseURL: String, provider: String, systemPrompt: String, prompt: String) async throws -> ChatResponse {
        try await request(
            ChatRequest(
                provider: provider,
                message: prompt,
                system: systemPrompt
            ),
            baseURL: baseURL,
            path: "/chat"
        )
    }

    func fetchExercise(baseURL: String, request: ExerciseGenerateRequest) async throws -> ExerciseGenerateResponse {
        try await self.request(request, baseURL: baseURL, path: "/exercise/generate")
    }

    func fetchReview(baseURL: String, request: ReviewRequest) async throws -> ReviewResponse {
        try await self.request(request, baseURL: baseURL, path: "/review")
    }

    func fetchHint(baseURL: String, request: HintRequest) async throws -> HintResponse {
        try await self.request(request, baseURL: baseURL, path: "/hint")
    }

    private func request<T: Decodable>(
        baseURL: String,
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        let url = try makeURL(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return try decoder.decode(T.self, from: data)
        } catch let error as ServiceError {
            throw error
        } catch let error as URLError {
            throw mapTransport(error)
        } catch {
            throw ServiceError.transport(error.localizedDescription)
        }
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ body: Body,
        baseURL: String,
        path: String
    ) async throws -> Response {
        let encodedBody = try encoder.encode(body)
        return try await request(baseURL: baseURL, path: path, method: "POST", body: encodedBody)
    }

    private func makeURL(baseURL: String, path: String) throws -> URL {
        let trimmedBaseURL = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !trimmedBaseURL.isEmpty, let url = URL(string: trimmedBaseURL + path), url.scheme != nil, url.host != nil else {
            throw ServiceError.invalidBaseURL(baseURL)
        }

        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let backendError = try? decoder.decode(BackendErrorResponse.self, from: data) {
                throw ServiceError.backend(statusCode: httpResponse.statusCode, message: backendError.error)
            }

            let message = httpResponse.statusCode >= 500
                ? "The server returned an unexpected response."
                : HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            throw ServiceError.http(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func mapTransport(_ error: URLError) -> ServiceError {
        switch error.code {
        case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            return .networkUnavailable
        default:
            return .transport(error.localizedDescription)
        }
    }
}
