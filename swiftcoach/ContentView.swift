import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel

    var body: some View {
        if !appState.selectedProvider.requiresLocalModel || appState.modelLoadingState == .loaded {
            AssistantWorkspaceView(appState: appState, aiViewModel: aiViewModel)
        } else {
            ModelDownloadView(
                state: appState.modelLoadingState,
                selectedModel: appState.selectedModelSize,
                retry: reloadModel
            )
        }
    }

    private func reloadModel() {
        guard appState.selectedProvider.requiresLocalModel else {
            appState.modelLoadingState = .loaded
            return
        }

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
