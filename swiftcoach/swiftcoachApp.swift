import SwiftUI

@main
struct swiftcoachApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var chatVM = ChatViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(chatVM)
                .task(id: appState.selectedModelSize.rawValue) {
                    appState.modelLoadingState = .downloading(progress: 0)
                    chatVM.loadModel(
                        modelID: appState.selectedModelSize.rawValue,
                        onProgress: { progress in
                            Task { @MainActor in
                                appState.modelLoadingState = progress >= 1
                                    ? .loaded
                                    : .downloading(progress: progress)
                            }
                        },
                        onFailure: { msg in
                            Task { @MainActor in
                                appState.modelLoadingState = .failed(msg)
                            }
                        }
                    )
                }
        }
    }
}
