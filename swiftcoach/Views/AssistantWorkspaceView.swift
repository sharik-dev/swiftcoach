import SwiftUI

struct AssistantWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel
    @StateObject private var editorViewModel: EditorViewModel

    init(appState: AppState, aiViewModel: AIViewModel) {
        _editorViewModel = StateObject(wrappedValue: EditorViewModel(aiViewModel: aiViewModel, appState: appState))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    modelCard
                    taskCard
                    contextCard
                    outputCard
                }
                .padding(16)
            }
            .navigationTitle("Swift Coach")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(aiViewModel.isThinking ? "Stop" : "Run") {
                        if aiViewModel.isThinking {
                            aiViewModel.cancelStream()
                        } else {
                            editorViewModel.generateNow()
                        }
                    }
                    .disabled(!editorViewModel.hasUsefulInput && !aiViewModel.isThinking)
                }
            }
        }
        .onChange(of: appState.inferenceDelay) {
            editorViewModel.refreshBindings()
        }
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider")
                .font(.headline)

            Picker("Provider", selection: $appState.selectedProvider) {
                ForEach(AppState.AIProvider.allCases) { provider in
                    Text(provider.displayName)
                        .tag(provider)
                }
            }
            .pickerStyle(.menu)

            Text(appState.selectedProvider.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if appState.selectedProvider.requiresLocalModel {
                Picker("Model", selection: $appState.selectedModelSize) {
                    ForEach(AppState.ModelSize.allCases) { model in
                        Text(model.displayName)
                            .tag(model)
                    }
                }
                .pickerStyle(.segmented)

                Text(appState.selectedModelSize.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Backend URL", text: $appState.backendBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend status")
                        .font(.subheadline.weight(.semibold))

                    if aiViewModel.remoteProviders.isEmpty {
                        Text("No provider metadata loaded yet. The backend will be checked when this mode is selected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(aiViewModel.remoteProviders) { provider in
                            HStack {
                                Text(provider.displayName)
                                Spacer()
                                Text(provider.configured ? "Ready" : "Missing server config")
                                    .foregroundStyle(provider.configured ? .green : .orange)
                            }
                            .font(.footnote)
                        }
                    }
                }
            }

            Toggle("Auto-run after inactivity", isOn: $appState.autoRunEnabled)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Debounce")
                    Spacer()
                    Text("\(appState.inferenceDelay, specifier: "%.1f") s")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $appState.inferenceDelay, in: 0.4...3.0, step: 0.2)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task")
                .font(.headline)

            TextEditor(text: $editorViewModel.taskText)
                .frame(minHeight: 130)
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Example: Refactor this SwiftUI view, fix a concurrency issue, or generate a unit test.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Code Context")
                .font(.headline)

            TextEditor(text: $editorViewModel.codeContext)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Response")
                    .font(.headline)
                Spacer()
                if aiViewModel.isThinking {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView {
                Text(aiViewModel.output.isEmpty ? emptyOutputMessage : aiViewModel.output)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(minHeight: 220)
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let error = aiViewModel.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyOutputMessage: String {
        if appState.selectedProvider.requiresLocalModel {
            return "The local model response will stream here."
        }

        return "The backend provider response will appear here."
    }
}
