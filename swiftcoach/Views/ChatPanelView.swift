import SwiftUI

struct ChatPanelView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.scLine)
            messageList
            Divider().background(Color.scLine)
            inputBar
        }
        .background(Color.scBg)
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.scAccent.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text("AI")
                    .font(.system(size: 9, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.scAccent)
            }
            Text("Assistant")
                .font(.system(size: 13).weight(.semibold))
                .foregroundStyle(Color.scInk2)
            Spacer()
            if chatVM.isStreaming {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(Color.scAccent2)
                    Text("Génération…")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.scBg2)
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if chatVM.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(chatVM.messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .onChange(of: chatVM.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom")
                }
            }
            .onChange(of: chatVM.messages.last?.content) { _, _ in
                proxy.scrollTo("bottom")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(Color.scInk4)
            Text("Pose une question ou clique sur\n« Analyser » dans l'éditeur")
                .font(.system(size: 13))
                .foregroundStyle(Color.scInk3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message…", text: $inputText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Color.scInk)
                .tint(Color.scAccent)
                .focused($inputFocused)
                .lineLimit(1...5)
                .onSubmit {
                    if !chatVM.isStreaming { sendMessage() }
                }

            Button(action: handleActionButton) {
                Image(systemName: chatVM.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(chatVM.isStreaming ? Color.scDanger : Color.scAccent)
            }
            .buttonStyle(.plain)
            .disabled(!chatVM.isStreaming && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.scBg2)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        chatVM.send(text: text)
    }

    private func handleActionButton() {
        if chatVM.isStreaming {
            chatVM.cancelStream()
        } else {
            sendMessage()
        }
    }
}

// MARK: - MessageRow

private struct MessageRow: View {
    let message: ChatViewModel.Message

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser { avatar }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
                let text = message.content.isEmpty && !isUser ? "…" : message.content
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(isUser ? Color.scInk : Color.scInk2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.scBg4 : Color.scBg3)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if isUser { userAvatar }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.scAccent.opacity(0.15)).frame(width: 26, height: 26)
            Text("AI")
                .font(.system(size: 9, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.scAccent)
        }
    }

    private var userAvatar: some View {
        ZStack {
            Circle().fill(Color.scBg4).frame(width: 26, height: 26)
            Image(systemName: "person.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.scInk3)
        }
    }
}

#Preview {
    ChatPanelView()
        .environmentObject(ChatViewModel())
        .frame(width: 360, height: 600)
}
