import SwiftUI

struct CodePanelView: View {
    @EnvironmentObject private var chatVM: ChatViewModel
    @State private var code = """
    func solution(_ nums: [Int], _ target: Int) -> [Int] {
        var seen: [Int: Int] = [:]
        for (i, n) in nums.enumerated() {
            if let j = seen[target - n] { return [j, i] }
            seen[n] = i
        }
        return []
    }
    """

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.scLine)
            editorArea
        }
        .background(Color.scShell)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
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
                .background(chatVM.isStreaming ? Color.scAccent.opacity(0.5) : Color.scAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(chatVM.isStreaming || !chatVM.isModelReady)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.scBg2)
    }

    private var editorArea: some View {
        TextEditor(text: $code)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(Color.scInk)
            .scrollContentBackground(.hidden)
            .background(Color.scShell)
            .padding(16)
    }

    private func analyzeCode() {
        chatVM.send(text: "Analyse ce code Swift et propose des améliorations.", codeContext: code)
    }
}

#Preview {
    CodePanelView()
        .environmentObject(ChatViewModel())
}
