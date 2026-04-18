import SwiftUI

struct ModelDownloadView: View {
    let state: ModelLoadingState
    let selectedModel: AppState.ModelSize
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.scShell.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Logo
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(colors: [Color.scAccent, Color.scAccent3],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("SC")
                            .font(.system(size: 16, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.black)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Swift Coach")
                            .font(.system(size: 26).weight(.bold))
                            .foregroundStyle(Color.scInk)
                        Text("Entraînement Swift piloté par un LLM coach.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.scInk3)
                    }
                }
                .padding(.bottom, 28)

                // Model card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "cpu")
                            .foregroundStyle(Color.scAccent2)
                        Text(selectedModel.displayName + " · code model")
                            .font(.system(size: 14).weight(.semibold))
                            .foregroundStyle(Color.scInk)
                    }

                    Text(selectedModel.rawValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.scInk3)
                        .lineLimit(2)

                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.scInk3)
                        Text("Téléchargement estimé : \(selectedModel.estimatedFootprint)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.scInk3)
                    }

                    Divider()
                        .background(Color.scLineSoft)

                    switch state {
                    case .notLoaded:
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color.scAccent)
                            Text("Initialisation…")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.scInk3)
                        }

                    case .downloading(let progress):
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Téléchargement du modèle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.scInk2)
                                Spacer()
                                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Color.scAccent)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.scBg3)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.scAccent)
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                    case .loaded:
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.scOk)
                            Text("Modèle prêt")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.scOk)
                        }

                    case .failed(let message):
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.scAccent5)
                                Text("Échec du chargement")
                                    .font(.system(size: 13).weight(.semibold))
                                    .foregroundStyle(Color.scAccent5)
                            }
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.scInk3)
                            Button(action: retry) {
                                Text("Réessayer")
                                    .font(.system(size: 13).weight(.semibold))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.scAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .background(Color.scBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.scLineSoft, lineWidth: 1)
                )

                Spacer()
                Spacer()
            }
            .padding(24)
        }
    }
}
