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

// MARK: - Mock data

extension Exercise {
    static let twoSum = Exercise(
        id: "twosum",
        topic: "Algorithmes",
        difficulty: "Intermédiaire",
        title: "Two Sum — version Swifty",
        brief: "Étant donné un tableau d'entiers `nums` et un entier `target`, retourne les indices des deux nombres dont la somme vaut `target`. Il existe exactement une solution, et tu ne peux pas utiliser le même élément deux fois.",
        constraints: [
            "2 ≤ nums.count ≤ 10⁴",
            "−10⁹ ≤ nums[i] ≤ 10⁹",
            "Solution en O(n) attendue"
        ],
        examples: [
            ExerciseExample(input: "nums = [2, 7, 11, 15], target = 9", output: "[0, 1]", note: "nums[0] + nums[1] == 9"),
            ExerciseExample(input: "nums = [3, 2, 4], target = 6",       output: "[1, 2]", note: nil)
        ],
        signature: "func twoSum(_ nums: [Int], _ target: Int) -> [Int]"
    )
}

let starterCode = """
func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var seen: [Int: Int] = [:]
    for (i, n) in nums.enumerated() {
        let complement = target - n
        if let j = seen[complement] {
            return [j, i]
        }
        seen[n] = i
    }
    return []
}

let result = twoSum([2, 7, 11, 15], 9)
print(result)
"""

let codeWithError = """
func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var seen: [Int: Int] = [:]
    for (i, n) in nums.enumerated() {
        let complement = target - n
        if let j = seen[complement]
            return [j, i]
        }
        seen[n] = i
    }
    return []
}

let result = twoSum([2, 7, 11, 15], 9)
print(result)
"""

let codeResolved = """
func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var indexByValue: [Int: Int] = [:]
    for (index, value) in nums.enumerated() {
        let complement = target - value
        if let matchIndex = indexByValue[complement] {
            return [matchIndex, index]
        }
        indexByValue[value] = index
    }
    return []
}

assert(twoSum([2, 7, 11, 15], 9) == [0, 1])
assert(twoSum([3, 2, 4], 6) == [1, 2])
print("✓ tous les cas passent")
"""

let annotationsSuccess: [Annotation] = [
    Annotation(line: 2, kind: .praise, title: "Bon choix de structure",
               body: "Un dictionnaire valeur→index donne du O(n). C'est la solution canonique."),
    Annotation(line: 4, kind: .nit, title: "Nommage",
               body: "`n` et `i` sont courts — `value` et `index` rendraient le code plus lisible."),
    Annotation(line: 10, kind: .suggestion, title: "Cas limite",
               body: "Que retourner si aucun couple n'existe ? `[Int]?` communiquerait mieux l'absence."),
]

let annotationsError: [Annotation] = [
    Annotation(line: 5, kind: .error, title: "Accolade manquante",
               body: "`if let j = seen[complement]` ouvre un bloc conditionnel mais il manque le `{` après la condition."),
]

let consoleLinesSuccess: [ConsoleLine] = [
    .init(kind: .cmd, text: "swift run twosum.swift"),
    .init(kind: .out, text: "Compiling twosum.swift…"),
    .init(kind: .out, text: "Build complete! (0.42s)"),
    .init(kind: .out, text: "[0, 1]"),
    .init(kind: .ok,  text: "Process exited with code 0"),
]

let consoleLinesError: [ConsoleLine] = [
    .init(kind: .cmd, text: "swift run twosum.swift"),
    .init(kind: .out, text: "Compiling twosum.swift…"),
    .init(kind: .err, text: "twosum.swift:5:38: error: expected '{' after 'if' condition"),
    .init(kind: .err, text: "        if let j = seen[complement]"),
    .init(kind: .err, text: "                                     ^"),
    .init(kind: .err, text: "Build failed (1 error)"),
]

let consoleLinesResolved: [ConsoleLine] = [
    .init(kind: .cmd, text: "swift run twosum.swift"),
    .init(kind: .out, text: "Compiling twosum.swift…"),
    .init(kind: .out, text: "Build complete! (0.38s)"),
    .init(kind: .out, text: "✓ tous les cas passent"),
    .init(kind: .ok,  text: "Process exited with code 0"),
]

let initialChatThread: [CoachMessage] = [
    CoachMessage(who: .user,  text: "Je veux un exo swift intermédiaire sur les dictionnaires.", time: "14:02"),
    CoachMessage(who: .coach, text: "Parfait. Je te propose Two Sum — version Swifty : un classique qui met en valeur [Int: Int] pour passer de O(n²) à O(n). J'ai chargé l'énoncé.", time: "14:02"),
    CoachMessage(who: .user,  text: "Ok j'attaque.", time: "14:03"),
]

let hints: [String] = [
    "Pour chaque `n`, tu cherches `target − n` — c'est ça que tu veux retrouver rapidement.",
    "Un `[Int: Int]` te donne une recherche en O(1) moyen. Clé : la valeur vue. Valeur : son index.",
    "Parcours `nums.enumerated()`. Si le complément existe dans le dico → retourne les deux indices. Sinon, stocke l'élément.",
]
