import SwiftUI

struct CodePanelView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @Binding var code: String

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.scLine)
            SyntaxEditorView(text: $code)
                .background(Color.scShell)
        }
        .background(Color.scShell)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.scAccent2)
                Text("Éditeur")
                    .font(.system(size: 13, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.scInk2)
            }
            Spacer()
            Button(action: analyzeCode) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text("Analyser")
                        .font(.system(size: 12).weight(.semibold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (chatVM.isStreaming || !chatVM.isModelReady)
                        ? Color.scAccent.opacity(0.4)
                        : Color.scAccent
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(chatVM.isStreaming || !chatVM.isModelReady)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.scBg2)
    }

    private func analyzeCode() {
        chatVM.send(
            text: "Analyse ce code Swift et propose des améliorations concrètes.",
            codeContext: code
        )
    }
}
