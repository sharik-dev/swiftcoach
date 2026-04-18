import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var chatVM: ChatViewModel

    var body: some View {
        if appState.modelLoadingState == .loaded {
            MainView()
        } else {
            ModelDownloadView(
                state: appState.modelLoadingState,
                selectedModel: appState.selectedModelSize,
                retry: retryLoad
            )
        }
    }

    private func retryLoad() {
        appState.modelLoadingState = .downloading(progress: 0)
        chatVM.loadModel(
            modelID: appState.selectedModelSize.rawValue,
            onProgress: { progress in
                Task { @MainActor in
                    appState.modelLoadingState = progress >= 1 ? .loaded : .downloading(progress: progress)
                }
            },
            onFailure: { msg in
                Task { @MainActor in appState.modelLoadingState = .failed(msg) }
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ChatViewModel())
}
