import SwiftUI
import Combine

@MainActor
final class CoachViewModel: ObservableObject {
    @Published var coachState: CoachState = .success
    @Published var code: String = starterCode
    @Published var chatThread: [CoachMessage] = initialChatThread
    @Published var draftMessage: String = ""
    @Published var briefCollapsed: Bool = false
    @Published var feedbackSheetOpen: Bool = true
    @Published var feedbackTab: FeedbackTab = .review

    let exercise: Exercise = .twoSum

    enum FeedbackTab { case review, chat }

    var annotations: [Annotation] {
        switch coachState {
        case .success:  return annotationsSuccess
        case .error:    return annotationsError
        default:        return []
        }
    }

    var consoleLines: [ConsoleLine] {
        switch coachState {
        case .success:  return consoleLinesSuccess
        case .error:    return consoleLinesError
        case .resolved: return consoleLinesResolved
        default:        return [.init(kind: .out, text: "// prêt. lance la compilation quand tu veux.")]
        }
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
            code = codeForState(state)
        }
        if state == .error || state == .success || state == .resolved || state == .hint {
            feedbackSheetOpen = true
        }
    }

    func run() {
        switch coachState {
        case .error:   setState(.success)
        case .success: setState(.resolved)
        default:       setState(.success)
        }
    }

    func requestHint() { setState(.hint) }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatThread.append(CoachMessage(who: .user, text: trimmed, time: timeString()))
        chatThread.append(CoachMessage(who: .coach, text: "Ok, je te prépare un exercice sur \(trimmed). Je garde celui en cours ouvert.", time: timeString()))
        draftMessage = ""
    }

    func appendCode(_ snippet: String) {
        code += snippet
    }

    private func codeForState(_ state: CoachState) -> String {
        switch state {
        case .error:    return codeWithError
        case .resolved: return codeResolved
        default:        return starterCode
        }
    }

    private func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}
