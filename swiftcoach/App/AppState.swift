import SwiftUI

enum ModelLoadingState: Equatable {
    case notLoaded
    case downloading(progress: Double)
    case loaded
    case failed(String)

    static func == (lhs: ModelLoadingState, rhs: ModelLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.notLoaded, .notLoaded), (.loaded, .loaded): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var modelLoadingState: ModelLoadingState = .notLoaded
    @Published var selectedModelSize: ModelSize = .balanced

    enum ModelSize: String, CaseIterable, Identifiable {
        case tiny     = "mlx-community/Qwen2.5-Coder-0.5B-Instruct-4bit"
        case balanced = "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit"
        case quality  = "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .tiny:     return "0.5B — Rapide"
            case .balanced: return "1.5B — Équilibré"
            case .quality:  return "3B — Qualité"
            }
        }

        var estimatedFootprint: String {
            switch self {
            case .tiny:     return "~278 Mo"
            case .balanced: return "~869 Mo"
            case .quality:  return "~1.74 Go"
            }
        }
    }
}
