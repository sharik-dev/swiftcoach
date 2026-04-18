import SwiftUI

struct CoachSidebarView: View {
    @ObservedObject var vm: CoachViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel

    private let quickTopics = ["Dictionnaires", "Optionals", "Protocols", "async/await", "Tri & recherche"]

    private var selectedRemoteProvider: RemoteProviderStatus? {
        guard let providerID = appState.selectedProvider.remoteProviderID else {
            return nil
        }

        return aiViewModel.remoteProviders.first(where: { $0.id == providerID })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(colors: [Color.scAccent, Color.scAccent3],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("SC")
                        .font(.system(size: 11, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.black)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Swift Coach")
                        .font(.system(size: 13).weight(.semibold))
                        .foregroundStyle(Color.scInk)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.scOk)
                            .frame(width: 6, height: 6)
                        Text("en ligne")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.scInk3)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Divider().background(Color.scLineSoft)
            }

            providerPanel
                .padding(12)
                .overlay(alignment: .bottom) {
                    Divider().background(Color.scLineSoft)
                }

            // Thread
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Text("Aujourd'hui · 14:02")
                            .font(.system(size: 10).weight(.medium))
                            .foregroundStyle(Color.scInk4)
                            .kerning(1.2)
                            .padding(.vertical, 12)

                        ForEach(vm.chatThread) { msg in
                            ChatBubbleView(msg: msg)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                                .id(msg.id)
                        }

                        // Quick topic buttons when in writing state
                        if vm.coachState == .writing {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DEMANDE UN THÈME")
                                    .font(.system(size: 10).weight(.semibold))
                                    .foregroundStyle(Color.scInk4)
                                    .kerning(1.2)
                                    .padding(.horizontal, 14)

                                ForEach(quickTopics, id: \.self) { topic in
                                    Button {
                                        vm.sendMessage(topic)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text("/")
                                                .font(.system(size: 12, design: .monospaced).weight(.bold))
                                                .foregroundStyle(Color.scAccent)
                                            Text(topic)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.scInk2)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 9)
                                        .background(Color.scBg2)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.scLineSoft, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .onChange(of: vm.chatThread.count) {
                    if let last = vm.chatThread.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Composer
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Demande un exo, un thème…", text: $vm.draftMessage, axis: .vertical)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.scInk)
                        .lineLimit(1...4)
                        .tint(Color.scAccent)

                    Button {
                        vm.sendMessage(vm.draftMessage)
                    } label: {
                        Text("↵")
                            .font(.system(size: 12, design: .monospaced).weight(.bold))
                            .foregroundStyle(vm.draftMessage.trimmingCharacters(in: .whitespaces).isEmpty ? Color.scInk3 : Color.black)
                            .frame(width: 28, height: 28)
                            .background(vm.draftMessage.trimmingCharacters(in: .whitespaces).isEmpty ? Color.scBg4 : Color.scAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.draftMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(10)
                .background(Color.scBg2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.scLineSoft, lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Text("⌘↵ envoyer")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.scInk4)
                    Text("/ thèmes")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.scInk4)
                }
            }
            .padding(12)
            .overlay(alignment: .top) {
                Divider().background(Color.scLineSoft)
            }
        }
        .background(Color(hex: "14141a"))
    }

    private var providerPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI PROVIDER")
                .font(.system(size: 10).weight(.semibold))
                .foregroundStyle(Color.scInk4)
                .kerning(1.2)

            Picker("Provider", selection: $appState.selectedProvider) {
                ForEach(AppState.AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)

            if appState.selectedProvider.requiresLocalModel {
                HStack(spacing: 8) {
                    Circle()
                        .fill(appState.modelLoadingState == .loaded ? Color.scOk : Color.scAccent5)
                        .frame(width: 8, height: 8)
                    Text(appState.selectedModelSize.displayName + " · " + appState.selectedModelSize.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk2)
                }
            } else {
                TextField("Backend URL", text: $appState.backendBaseURL)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.scBg2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.scLineSoft, lineWidth: 1)
                    )

                if let provider = selectedRemoteProvider {
                    VStack(alignment: .leading, spacing: 6) {
                        providerMetaRow(label: "Status", value: provider.statusLabel, tone: provider.isReady ? .scOk : .scAccent5)
                        providerMetaRow(label: "Transport", value: provider.transportLabel, tone: Color.scInk2)
                        providerMetaRow(label: "Model", value: provider.model, tone: Color.scInk3)
                    }
                } else {
                    Text("Select a backend provider to see live status.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk3)
                }

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await aiViewModel.refreshRemoteProviders(
                                baseURL: appState.backendBaseURL,
                                selectedProviderID: appState.selectedProvider.remoteProviderID
                            )
                        }
                    } label: {
                        Text("Refresh")
                            .font(.system(size: 11).weight(.semibold))
                            .foregroundStyle(Color.scInk2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.scBg2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await aiViewModel.testSelectedProvider(
                                provider: appState.selectedProvider,
                                backendBaseURL: appState.backendBaseURL
                            )
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if aiViewModel.isTestingProvider {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(aiViewModel.isTestingProvider ? "Testing..." : "Test Provider")
                                .font(.system(size: 11).weight(.bold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.scAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(aiViewModel.isTestingProvider)
                }

                if let result = aiViewModel.providerTestResult {
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk2)
                        .lineLimit(3)
                }
            }
        }
    }

    private func providerMetaRow(label: String, value: String, tone: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9).weight(.semibold))
                .foregroundStyle(Color.scInk4)
                .kerning(1)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(tone)
                .lineLimit(1)
        }
    }
}
