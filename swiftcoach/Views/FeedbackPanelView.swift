import SwiftUI

struct FeedbackPanelView: View {
    @ObservedObject var coachVM: CoachViewModel

    private var summary: (tone: SCPillTone, title: String, body: String) {
        switch coachVM.coachState {
        case .error:
            return (.red, "Build échoué", "Une erreur de syntaxe bloque la compilation. Je l'ai pointée dans le code.")
        case .success:
            return (.green, "Build OK", "Sortie `[0, 1]` obtenue. Quelques remarques de lisibilité avant de valider.")
        case .resolved:
            return (.green, "Résolu ✓", "Tous les tests passent. Refactor propre, prêt pour l'exercice suivant.")
        case .hint:
            return (.warm, "Indice", "Je te donne un coup de pouce sans spoiler la solution.")
        case .writing:
            return (.neutral, "Prêt", "Compile quand tu veux. J'analyse ton code dès que tu lances.")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("FEEDBACK")
                        .font(.system(size: 10).weight(.semibold))
                        .foregroundStyle(Color.scInk3)
                        .kerning(1.4)
                    SCPill(label: summary.title, tone: summary.tone)
                    Spacer()
                    Text("quelques secondes")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk4)
                }
                Text(summary.body)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.scInk2)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Tabs
            HStack(spacing: 0) {
                FeedbackTabButton(label: "Revue", badge: coachVM.annotations.isEmpty ? nil : "\(coachVM.annotations.count)",
                            active: coachVM.feedbackTab == .review) { coachVM.feedbackTab = .review }
                FeedbackTabButton(label: "Chat", badge: "\(coachVM.chatThread.count)", active: coachVM.feedbackTab == .chat) { coachVM.feedbackTab = .chat }
            }
            .padding(.horizontal, 10)
            .overlay(alignment: .bottom) {
                Divider().background(Color.scLineSoft)
            }

            // Content
            ScrollView {
                if coachVM.feedbackTab == .review {
                    ReviewTabContent(
                        annotations: coachVM.annotations,
                        state: coachVM.coachState,
                        hints: coachVM.progressiveHints,
                        onHint: coachVM.requestHint
                    )
                        .padding(12)
                } else {
                    ChatTabContent(
                        messages: coachVM.chatThread,
                        draftMessage: $coachVM.draftMessage,
                        onSend: coachVM.sendMessage
                    )
                        .padding(12)
                }
            }
        }
    }
}

private struct FeedbackTabButton: View {
    let label: String
    let badge: String?
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12).weight(.medium))
                    .foregroundStyle(active ? Color.scInk : Color.scInk3)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.scInk2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.scBg3)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                if active {
                    Rectangle()
                        .fill(Color.scAccent)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewTabContent: View {
    let annotations: [Annotation]
    let state: CoachState
    let hints: [String]
    let onHint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if annotations.isEmpty {
                VStack(spacing: 6) {
                    Text("Aucune remarque pour le moment.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.scInk3)
                    Text("Compile ton code pour déclencher une revue.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.scInk4)
                    if state == .writing {
                        Button("Demander un indice", action: onHint)
                            .font(.system(size: 12).weight(.medium))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.scAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(annotations) { ann in
                    ReviewItemView(ann: ann)
                }
            }

            if state == .hint {
                HintSectionView(hints: hints)
            }
        }
    }
}

struct ReviewItemView: View {
    let ann: Annotation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ann.kind.accentColor)
                        .frame(width: 20, height: 20)
                    Text(String(ann.kind.rawValue.prefix(1)).uppercased())
                        .font(.system(size: 11, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.black)
                }
                Text(ann.title)
                    .font(.system(size: 13).weight(.semibold))
                    .foregroundStyle(Color.scInk)
                Spacer()
                Text("L\(ann.line)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.scInk4)
            }
            Text(ann.body)
                .font(.system(size: 12))
                .foregroundStyle(Color.scInk2)
                .lineSpacing(3)
        }
        .padding(12)
        .background(ann.kind.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(ann.kind.accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HintSectionView: View {
    let hints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INDICES PROGRESSIFS")
                .font(.system(size: 10, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.scAccent)
                .kerning(1.2)

            ForEach(Array(hints.enumerated()), id: \.offset) { i, hint in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1).")
                        .font(.system(size: 12, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.scAccent)
                        .frame(width: 16)
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.scInk2)
                        .lineSpacing(3)
                }
            }
        }
        .padding(12)
        .background(Color.scAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.scAccent.opacity(0.30), lineWidth: 1)
        )
    }
}

private struct ChatTabContent: View {
    let messages: [CoachMessage]
    @Binding var draftMessage: String
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(messages) { msg in
                ChatBubbleView(msg: msg)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Pose une question au coach…", text: $draftMessage, axis: .vertical)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.scInk)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)

                Button {
                    onSend(draftMessage)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12).weight(.bold))
                        .foregroundStyle(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.scInk3 : Color.black)
                        .frame(width: 30, height: 30)
                        .background(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.scBg4 : Color.scAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color.scBg2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct ChatBubbleView: View {
    let msg: CoachMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CoachAvatarView(who: msg.who)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(msg.who == .coach ? "Coach" : "Moi")
                        .font(.system(size: 11).weight(.semibold))
                        .foregroundStyle(msg.who == .coach ? Color.scAccent : Color.scInk2)
                    Spacer()
                    Text(msg.time)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.scInk3)
                }
                Text(msg.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.scInk)
                    .lineSpacing(3)
            }
        }
    }
}

struct CoachAvatarView: View {
    let who: CoachMessage.Who

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(who == .coach
                    ? LinearGradient(colors: [Color.scAccent, Color.scAccent3], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.scBg4, Color.scBg4], startPoint: .top, endPoint: .bottom)
                )
            Text(who == .coach ? "SC" : "ME")
                .font(.system(size: 9, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.black)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Console Panel

struct ConsolePanelView: View {
    let lines: [ConsoleLine]
    let onClear: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("Console")
                    .font(.system(size: 11).weight(.semibold))
                    .foregroundStyle(Color.scInk2)
                Text("swift-driver 5.10")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.scInk4)
                Spacer()
                Button("clear ⌫") {
                    onClear?()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.scInk4)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.scBg2)
            .overlay(alignment: .bottom) {
                Divider().background(Color.scLineSoft)
            }

            // Output
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lines) { line in
                        HStack(spacing: 0) {
                            if line.kind == .cmd {
                                Text("$ ")
                                    .foregroundStyle(Color.scAccent)
                            }
                            Text(line.text)
                                .foregroundStyle(line.color)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.scShell)
    }
}
