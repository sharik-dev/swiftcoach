import SwiftUI

// MARK: - Data models

struct Exercise: Identifiable {
    let id: String
    let topic: String
    let difficulty: String
    let title: String
    let brief: String
    let constraints: [String]
    let examples: [ExerciseExample]
    let signature: String
}

struct ExerciseExample {
    let input: String
    let output: String
    let note: String?
}

struct Annotation: Identifiable {
    let id = UUID()
    let line: Int
    let kind: Kind
    let title: String
    let body: String

    enum Kind: String {
        case error, praise, nit, suggestion

        var accentColor: Color {
            switch self {
            case .error:      return .scDanger
            case .praise:     return .scAccent4
            case .nit:        return .scAccent5
            case .suggestion: return .scAccent2
            }
        }

        var label: String {
            switch self {
            case .error:      return "Erreur"
            case .praise:     return "Bien"
            case .nit:        return "Nit"
            case .suggestion: return "Piste"
            }
        }
    }
}

struct ConsoleLine: Identifiable {
    let id = UUID()
    let kind: Kind
    let text: String

    enum Kind { case cmd, out, err, ok }

    var color: Color {
        switch kind {
        case .cmd: return .scInk
        case .out: return .scInk2
        case .err: return .scDanger
        case .ok:  return .scOk
        }
    }
}

struct CoachMessage: Identifiable {
    let id = UUID()
    let who: Who
    let text: String
    let time: String

    enum Who { case user, coach }
}

enum CoachState: String, CaseIterable {
    case writing  = "En écriture"
    case hint     = "Indice"
    case error    = "Erreur compilation"
    case success  = "Succès + feedback"
    case resolved = "Résolu"
}

extension Exercise {
    static let placeholder = Exercise(
        id: "placeholder",
        topic: "Swift",
        difficulty: "Intermédiaire",
        title: "En attente…",
        brief: "Demande un exercice au coach pour commencer. Essaie : \"Je veux un exo sur les dictionnaires\" ou clique sur un thème rapide.",
        constraints: [],
        examples: [],
        signature: "// Génère un exercice pour commencer"
    )
}
