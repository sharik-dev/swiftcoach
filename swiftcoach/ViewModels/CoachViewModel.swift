import SwiftUI

@MainActor
final class CoachViewModel: ObservableObject {
    typealias AIResponder = @Sendable (_ task: String, _ codeContext: String) async throws -> String

    @Published var coachState: CoachState = .writing
    @Published var code: String
    @Published var chatThread: [CoachMessage]
    @Published var draftMessage: String = ""
    @Published var briefCollapsed: Bool = false
    @Published var feedbackSheetOpen: Bool = true
    @Published var feedbackTab: FeedbackTab = .review
    @Published var consoleLines: [ConsoleLine]
    @Published var isCoachThinking = false

    let exercise: Exercise
    let dataSource: AppState.ExerciseDataSource
    private let aiResponder: AIResponder?

    enum FeedbackTab { case review, chat }

    init(
        dataSource: AppState.ExerciseDataSource = .demo,
        aiResponder: AIResponder? = nil
    ) {
        self.dataSource = dataSource
        self.exercise = CoachDemoData.exercise
        self.code = CoachDemoData.starterCode
        self.chatThread = CoachDemoData.initialChatThread
        self.consoleLines = [CoachDemoData.idleConsoleLine]
        self.aiResponder = aiResponder
    }

    var annotations: [Annotation] {
        switch coachState {
        case .success:  return CoachDemoData.annotationsSuccess
        case .error:    return CoachDemoData.annotationsError
        default:        return []
        }
    }

    var progressiveHints: [String] {
        CoachDemoData.hints
    }

    var buildStatusLabel: String {
        switch coachState {
        case .error:    return "échec build"
        case .success:  return "build ok"
        case .resolved: return "résolu"
        default:        return "prêt"
        }
    }

    var buildStatusColor: Color {
        switch coachState {
        case .error:    return .scDanger
        case .success, .resolved: return .scOk
        default:        return .scInk4
        }
    }

    func setState(_ state: CoachState) {
        withAnimation(.easeInOut(duration: 0.2)) {
            coachState = state
            switch state {
            case .error, .resolved:
                code = codeForState(state)
            case .success where code.trimmingCharacters(in: .whitespacesAndNewlines) == CoachDemoData.starterCode.trimmingCharacters(in: .whitespacesAndNewlines):
                code = codeForState(state)
            default:
                break
            }
        }
        if state == .error || state == .success || state == .resolved || state == .hint || state == .writing {
            feedbackSheetOpen = true
        }
        syncConsole(for: state)
    }

    func run() {
        let compilation = evaluateCode(code)
        coachState = compilation.state
        consoleLines = compilation.console
        feedbackSheetOpen = true
        feedbackTab = .review

        Task {
            let fallback: String
            let task: String

            switch compilation.state {
            case .error:
                fallback = "La compilation casse sur un détail de syntaxe. Regarde la ligne signalée dans la console et la revue."
                task = "Review this Swift code after a failed compile. Explain the error briefly and give the smallest fix. Keep it concise."
            case .success:
                fallback = "La solution compile et retourne le bon résultat sur l'exemple. Je t'ai laissé une revue rapide."
                task = "Review this Swift exercise solution. Give 2 or 3 concise code review comments in French, focused on readability and correctness."
            case .resolved:
                fallback = "Bien joué. Là on est sur une version propre et validée avec assertions."
                task = "The Swift exercise is solved. Give a short French coach message: validation, one strength, and one next-step challenge."
            case .writing, .hint:
                return
            }

            let response = await askAI(task: task, fallback: fallback)
            appendCoachMessage(response)
        }
    }

    func requestHint() {
        coachState = .hint
        feedbackSheetOpen = true
        feedbackTab = .review
        syncConsole(for: .hint)
        Task {
            let index = min(chatThread.filter { $0.who == .coach }.count % progressiveHints.count, progressiveHints.count - 1)
            let fallback = progressiveHints[index]
            let response = await askAI(
                task: "Give one concise French hint for this Swift exercise without revealing the full solution.",
                fallback: fallback
            )
            appendCoachMessage(response)
        }
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatThread.append(CoachMessage(who: .user, text: trimmed, time: timeString()))
        draftMessage = ""
        feedbackTab = .chat
        feedbackSheetOpen = true
        Task {
            let response = await askAI(
                task: "Answer the user's coaching message in French as a concise Swift coding coach. User message: \(trimmed)",
                fallback: response(to: trimmed)
            )
            appendCoachMessage(response)
        }
    }

    func appendCode(_ snippet: String) {
        code += snippet
        if coachState != .writing {
            coachState = .writing
            syncConsole(for: .writing)
        }
    }

    func clearConsole() {
        consoleLines = [.init(kind: .out, text: "// console vidée")]
    }

    private func codeForState(_ state: CoachState) -> String {
        switch state {
        case .error:    return CoachDemoData.codeWithError
        case .resolved: return CoachDemoData.codeResolved
        default:        return CoachDemoData.starterCode
        }
    }

    private func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func appendCoachMessage(_ text: String) {
        chatThread.append(CoachMessage(who: .coach, text: text, time: timeString()))
    }

    private func askAI(task: String, fallback: String) async -> String {
        guard let aiResponder else { return fallback }
        isCoachThinking = true
        defer { isCoachThinking = false }

        do {
            return try await aiResponder(task, code)
        } catch {
            consoleLines.append(.init(kind: .err, text: "coach ai fallback: \(error.localizedDescription)"))
            return fallback
        }
    }

    private func response(to prompt: String) -> String {
        let lowercased = prompt.lowercased()

        if lowercased.contains("indice") || lowercased.contains("help") || lowercased.contains("bloqu") {
            return progressiveHints.first ?? "Commence par chercher une structure qui te donne le complément en O(1)."
        }

        if lowercased.contains("error") || lowercased.contains("erreur") || lowercased.contains("compile") {
            return "Relance la compilation depuis le bouton. Je brancherai la console sur la dernière sortie et je pointerai la ligne fautive."
        }

        if lowercased.contains("test") || lowercased.contains("assert") {
            return "Ajoute deux assertions minimales sur les cas de l'énoncé. Si elles passent, tu peux considérer l'exercice résolu."
        }

        return "Je garde l'exercice courant. Si tu veux, je peux te donner un indice, relire ton code, ou te proposer une variante après validation."
    }

    private func syncConsole(for state: CoachState) {
        switch state {
        case .error:
            consoleLines = CoachDemoData.consoleLinesError
        case .success:
            consoleLines = CoachDemoData.consoleLinesSuccess
        case .resolved:
            consoleLines = CoachDemoData.consoleLinesResolved
        case .writing:
            consoleLines = [CoachDemoData.idleConsoleLine]
        case .hint:
            consoleLines = [
                .init(kind: .cmd, text: "coach hint"),
                .init(kind: .out, text: progressiveHints.first ?? "Cherche le complément dans un dictionnaire.")
            ]
        }
    }

    private func evaluateCode(_ source: String) -> (state: CoachState, console: [ConsoleLine]) {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")

        if normalized.contains("if let j = seen[complement]\n") || normalized.contains("if let j = seen[complement]\n            return") {
            return (.error, CoachDemoData.consoleLinesError)
        }

        let hasAssertions = normalized.contains("assert(")
        let hasRefinedNaming = normalized.contains("indexByValue") || normalized.contains("matchIndex")
        let printsResult = normalized.contains("print(")

        if hasAssertions && hasRefinedNaming {
            return (.resolved, CoachDemoData.consoleLinesResolved)
        }

        if printsResult {
            return (.success, CoachDemoData.consoleLinesSuccess)
        }

        return (
            .success,
            [
                .init(kind: .cmd, text: "swift run twosum.swift"),
                .init(kind: .out, text: "Compiling twosum.swift…"),
                .init(kind: .out, text: "Build complete! (0.40s)"),
                .init(kind: .ok, text: "Process exited with code 0")
            ]
        )
    }
}
