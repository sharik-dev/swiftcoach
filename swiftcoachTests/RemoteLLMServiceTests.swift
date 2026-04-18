import Foundation
import XCTest
@testable import swiftcoach

final class RemoteLLMServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchProvidersSuccess() async throws {
        let service = makeService { request in
            XCTAssertEqual(request.url?.path, "/providers")
            let body = """
            {"providers":[{"id":"codex","model":"gpt-5.4","configured":true}]}
            """
            return try self.response(statusCode: 200, body: body)
        }

        let providers = try await service.fetchProviders(baseURL: "http://127.0.0.1:3000")

        XCTAssertEqual(providers, [.init(id: "codex", model: "gpt-5.4", configured: true)])
    }

    func testGenerateChatSuccess() async throws {
        let service = makeService { request in
            XCTAssertEqual(request.url?.path, "/chat")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = """
            {"provider":"codex","model":"gpt-5.4","output":"Salut"}
            """
            return try self.response(statusCode: 200, body: body)
        }

        let response = try await service.generate(
            baseURL: "http://127.0.0.1:3000",
            provider: "codex",
            systemPrompt: "system",
            prompt: "hello"
        )

        XCTAssertEqual(response.output, "Salut")
    }

    func testBackendErrorMessageFrom4xx() async {
        let service = makeService { request in
            XCTAssertEqual(request.url?.path, "/chat")
            return try self.response(statusCode: 400, body: #"{"error":"Provider not configured"}"#)
        }

        do {
            _ = try await service.generate(
                baseURL: "http://127.0.0.1:3000",
                provider: "codex",
                systemPrompt: "system",
                prompt: "hello"
            )
            XCTFail("Expected backend error")
        } catch let error as RemoteLLMService.ServiceError {
            XCTAssertEqual(error, .backend(statusCode: 400, message: "Provider not configured"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServerErrorWithoutBackendMessage() async {
        let service = makeService { _ in
            try self.response(statusCode: 500, body: #"{"unexpected":"shape"}"#)
        }

        do {
            _ = try await service.fetchProviders(baseURL: "http://127.0.0.1:3000")
            XCTFail("Expected server error")
        } catch let error as RemoteLLMService.ServiceError {
            XCTAssertEqual(error, .http(statusCode: 500, message: "The server returned an unexpected response."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidURL() async {
        let service = makeService { _ in
            XCTFail("Network should not be reached for invalid URL")
            return try self.response(statusCode: 200, body: "{}")
        }

        do {
            _ = try await service.fetchProviders(baseURL: "not a valid url")
            XCTFail("Expected invalid URL")
        } catch let error as RemoteLLMService.ServiceError {
            XCTAssertEqual(error, .invalidBaseURL("not a valid url"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBackendUnavailable() async {
        let service = makeService { _ in
            throw URLError(.cannotConnectToHost)
        }

        do {
            _ = try await service.fetchProviders(baseURL: "http://127.0.0.1:3000")
            XCTFail("Expected connectivity error")
        } catch let error as RemoteLLMService.ServiceError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService(handler: @escaping MockURLProtocol.Handler) -> RemoteLLMService {
        MockURLProtocol.requestHandler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return RemoteLLMService(session: session)
    }

    private func response(statusCode: Int, body: String) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:3000/test"))
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (response, Data(body.utf8))
    }
}

private final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    static var requestHandler: Handler?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
