import SwiftUI

@main
struct swiftcoachApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var aiViewModel = AIViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(aiViewModel)
                .task(id: appState.configurationToken) {
                    if appState.selectedProvider.requiresLocalModel {
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
                    } else {
                        appState.modelLoadingState = .loaded
                        await aiViewModel.refreshRemoteProviders(
                            baseURL: appState.backendBaseURL,
                            selectedProviderID: appState.selectedProvider.remoteProviderID
                        )
                    }
                }
        }
    }
}
