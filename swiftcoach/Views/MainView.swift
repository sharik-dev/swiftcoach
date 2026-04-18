import SwiftUI

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
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
        if sizeClass == .regular {
            // iPad & iPhone landscape — côte à côte
            HStack(spacing: 0) {
                CodePanelView(code: $code)
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(Color.scLine)
                    .frame(width: 1)
                ChatPanelView()
                    .frame(width: 340)
            }
            .background(Color.scShell)
            .ignoresSafeArea(edges: .bottom)
        } else {
            // iPhone portrait — empilé verticalement
            GeometryReader { geo in
                VStack(spacing: 0) {
                    CodePanelView(code: $code)
                        .frame(height: geo.size.height * 0.52)
                    Rectangle()
                        .fill(Color.scLine)
                        .frame(height: 1)
                    ChatPanelView()
                        .frame(maxHeight: .infinity)
                }
            }
            .background(Color.scShell)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
        .environmentObject(ChatViewModel())
}
