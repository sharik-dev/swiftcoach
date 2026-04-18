import SwiftUI

struct ModelDownloadView: View {
    let state: ModelLoadingState
    let selectedModel: AppState.ModelSize
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            Text("Swift Coach")
                .font(.largeTitle.bold())

            Text("Local code assistant running with MLX on-device.")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label(selectedModel.displayName + " code model", systemImage: "cpu")
                    .font(.headline)

                Text(selectedModel.rawValue)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)

                Text("Estimated download: \(selectedModel.estimatedFootprint)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                switch state {
                case .notLoaded:
                    ProgressView()
                case .downloading(let progress):
                    ProgressView(value: progress) {
                        Text("Downloading model")
                    } currentValueLabel: {
                        Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    }
                case .loaded:
                    Label("Model ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed(let message):
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Model loading failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Retry", action: retry)
                    }
                }
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.22), Color.cyan.opacity(0.12), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
