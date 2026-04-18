import Combine
import Foundation

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var taskText = ""
    @Published var codeContext = ""

    private var cancellables = Set<AnyCancellable>()
    private let aiViewModel: AIViewModel
    private let appState: AppState

    init(aiViewModel: AIViewModel, appState: AppState) {
        self.aiViewModel = aiViewModel
        self.appState = appState
        setupBindings()
    }

    func refreshBindings() {
        cancellables.removeAll()
        setupBindings()
    }

    func generateNow() {
        guard hasUsefulInput else { return }
        aiViewModel.generate(task: taskText, codeContext: codeContext)
    }

    var hasUsefulInput: Bool {
        !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !codeContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func setupBindings() {
        Publishers.CombineLatest($taskText.dropFirst(), $codeContext.dropFirst())
            .debounce(for: .seconds(appState.inferenceDelay), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self, self.appState.autoRunEnabled else { return }
                self.generateNow()
            }
            .store(in: &cancellables)
    }
}
