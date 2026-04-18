import Foundation

struct RemoteProviderStatus: Codable, Identifiable, Equatable {
    let id: String
    let model: String
    let configured: Bool

    var displayName: String {
        id.capitalized
    }
}

struct ProvidersResponse: Codable, Equatable {
    let providers: [RemoteProviderStatus]
}

struct ChatRequest: Codable, Equatable {
    let provider: String
    let message: String
    let system: String
}

struct ChatResponse: Codable, Equatable {
    let provider: String
    let model: String
    let output: String
}

struct ExerciseGenerateRequest: Codable, Equatable {
    let provider: String
    let topic: String?
    let difficulty: String?
    let userPrompt: String?
}

struct ExerciseGenerateResponse: Codable, Equatable {
    let exercise: BackendExercise
    let starterCode: String
    let hints: [String]
}

struct BackendExercise: Codable, Equatable {
    let id: String
    let topic: String
    let difficulty: String
    let title: String
    let brief: String
    let constraints: [String]
    let examples: [BackendExerciseExample]
    let signature: String
}

struct BackendExerciseExample: Codable, Equatable {
    let input: String
    let output: String
    let note: String?
}

struct ReviewRequest: Codable, Equatable {
    let provider: String
    let exerciseID: String
    let code: String
    let consoleOutput: String?
    let languageHint: String?
}

struct ReviewResponse: Codable, Equatable {
    let summary: String
    let state: String
    let annotations: [ReviewAnnotation]
    let hint: String?
}

struct ReviewAnnotation: Codable, Equatable {
    let line: Int
    let kind: String
    let title: String
    let body: String
}

struct HintRequest: Codable, Equatable {
    let provider: String
    let exerciseID: String
    let code: String
    let userMessage: String?
}

struct HintResponse: Codable, Equatable {
    let hint: String
}

struct CompileRequest: Codable, Equatable {
    let language: String
    let filename: String
    let code: String
}

struct CompileResponse: Codable, Equatable {
    let success: Bool
    let stdout: String
    let stderr: String
    let exitCode: Int
}

struct BackendErrorResponse: Codable, Equatable {
    let error: String
}
