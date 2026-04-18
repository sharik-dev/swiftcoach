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
    @Published var selectedModelSize: ModelSize = .balanced
    @Published var inferenceDelay: Double = 1.2
    @Published var autoRunEnabled = true

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
