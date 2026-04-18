import SwiftUI

enum ModelLoadingState: Equatable {
    case notLoaded
    case downloading(progress: Double)
    case loaded
    case failed(String)

    static func == (lhs: ModelLoadingState, rhs: ModelLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded), (.loaded, .loaded):
            return true
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var modelLoadingState: ModelLoadingState = .notLoaded
    @Published var selectedProvider: AIProvider = .local
    @Published var selectedModelSize: ModelSize = .balanced
    @Published var exerciseDataSource: ExerciseDataSource = .demo
    @Published var backendBaseURL: String = "http://127.0.0.1:3010"
    @Published var inferenceDelay: Double = 1.2
    @Published var autoRunEnabled = true

    var configurationToken: String {
        "\(selectedProvider.rawValue)|\(selectedModelSize.rawValue)|\(backendBaseURL)"
    }

    enum AIProvider: String, CaseIterable, Identifiable {
        case local
        case codex
        case claude
        case gemma

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .local:
                return "Local MLX"
            case .codex:
                return "Codex"
            case .claude:
                return "Claude"
            case .gemma:
                return "Gemma"
            }
        }

        var subtitle: String {
            switch self {
            case .local:
                return "On-device inference with an MLX code model"
            case .codex:
                return "Backend provider via OpenAI"
            case .claude:
                return "Backend provider via Anthropic"
            case .gemma:
                return "Backend provider via Ollama"
            }
        }

        var requiresLocalModel: Bool {
            self == .local
        }

        var remoteProviderID: String? {
            switch self {
            case .local:
                return nil
            case .codex:
                return "codex"
            case .claude:
                return "claude"
            case .gemma:
                return "gemma"
            }
        }
    }

    enum ExerciseDataSource: String, CaseIterable, Identifiable {
        case demo
        case remote
        case local

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .demo:
                return "Demo"
            case .remote:
                return "Remote"
            case .local:
                return "Local"
            }
        }
    }

    enum ModelSize: String, CaseIterable, Identifiable {
        case tiny = "mlx-community/Qwen2.5-Coder-0.5B-Instruct-4bit"
        case balanced = "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit"
        case quality = "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .tiny:
                return "0.5B"
            case .balanced:
                return "1.5B"
            case .quality:
                return "3B"
            }
        }

        var subtitle: String {
            switch self {
            case .tiny:
                return "Fastest, best for quick completions"
            case .balanced:
                return "Best default for code assistance"
            case .quality:
                return "Higher quality, more RAM and latency"
            }
        }

        var estimatedFootprint: String {
            switch self {
            case .tiny:
                return "~278 MB"
            case .balanced:
                return "~869 MB"
            case .quality:
                return "~1.74 GB"
            }
        }
    }
}
