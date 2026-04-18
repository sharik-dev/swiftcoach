import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel

    var body: some View {
        switch appState.modelLoadingState {
        case .loaded:
            AssistantWorkspaceView(appState: appState, aiViewModel: aiViewModel)
        case .notLoaded, .downloading, .failed:
            ModelDownloadView(
                state: appState.modelLoadingState,
                selectedModel: appState.selectedModelSize,
                retry: reloadModel
            )
        }
    }

    private func reloadModel() {
        let modelID = appState.selectedModelSize.rawValue
        appState.modelLoadingState = .downloading(progress: 0)

        aiViewModel.ensureModelLoaded(
            modelID: modelID,
            progressHandler: { progress in
                Task { @MainActor in
                    appState.modelLoadingState = progress >= 1 ? .loaded : .downloading(progress: progress)
                }
            },
            failureHandler: { message in
                Task { @MainActor in
                    appState.modelLoadingState = .failed(message)
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AIViewModel())
}
