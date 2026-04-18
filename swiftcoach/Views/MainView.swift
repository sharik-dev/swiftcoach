import SwiftUI

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            splitLayout
        } else {
            tabLayout
        }
    }

    // iPad / landscape — éditeur à gauche, chat à droite
    private var splitLayout: some View {
        HStack(spacing: 0) {
            CodePanelView()
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(Color.scLine)
                .frame(width: 1)
            ChatPanelView()
                .frame(width: 360)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // iPhone — deux onglets
    private var tabLayout: some View {
        TabView {
            CodePanelView()
                .tabItem { Label("Code", systemImage: "doc.text") }
            ChatPanelView()
                .tabItem { Label("Assistant", systemImage: "bubble.left") }
        }
        .toolbarBackground(Color.scBg2, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
        .environmentObject(ChatViewModel())
}
