import SwiftUI

@MainActor
final class CoachViewModel: ObservableObject {
    typealias AIResponder = @Sendable (_ task: String, _ codeContext: String) async throws -> String

    @Published var coachState: CoachState = .writing
    @Published var code: String = ""
    @Published var selectedRange: NSRange = .init(location: 0, length: 0)
    @Published var exercise: Exercise = .placeholder
    @Published var annotations: [Annotation] = []
    @Published var progressiveHints: [String] = []
    @Published var chatThread: [CoachMessage] = []
    @Published var draftMessage: String = ""
    @Published var briefCollapsed: Bool = false
    @Published var feedbackSheetOpen: Bool = true
    @Published var feedbackTab: FeedbackTab = .review
    @Published var consoleLines: [ConsoleLine] = [.init(kind: .out, text: "// prêt. lance la compilation quand tu veux.")]
    @Published var isCoachThinking = false

    let dataSource: AppState.ExerciseDataSource
    private let aiResponder: AIResponder?

    enum FeedbackTab { case review, chat }

    init(dataSource: AppState.ExerciseDataSource = .demo, aiResponder: AIResponder? = nil) {
        self.dataSource = dataSource
        self.aiResponder = aiResponder

        if dataSource == .demo {
            exercise = CoachDemoData.exercise
            code = CoachDemoData.starterCode
            selectedRange = NSRange(location: CoachDemoData.starterCode.count, length: 0)
            chatThread = CoachDemoData.initialChatThread
            consoleLines = [CoachDemoData.idleConsoleLine]
            progressiveHints = CoachDemoData.hints
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
            if dataSource == .demo {
                switch state {
                case .error:
                    code = CoachDemoData.codeWithError
                    selectedRange = NSRange(location: CoachDemoData.codeWithError.count, length: 0)
                    annotations = CoachDemoData.annotationsError
                case .success:
                    annotations = CoachDemoData.annotationsSuccess
                case .resolved:
                    code = CoachDemoData.codeResolved
                    selectedRange = NSRange(location: CoachDemoData.codeResolved.count, length: 0)
                    annotations = []
                default:
                    annotations = []
                }
                syncDemoConsole(for: state)
            }
        }
        feedbackSheetOpen = true
    }

    func run() {
        let compilation = evaluateCode(code)
        coachState = compilation.state
        feedbackSheetOpen = true
        feedbackTab = .review

        if dataSource == .demo {
            consoleLines = demoConsoleLines(for: compilation.state)
            annotations = demoAnnotations(for: compilation.state)
            Task {
                let task: String
                let fallback: String
                switch compilation.state {
                case .error:
                    task = "Review this Swift code after a failed compile. Explain the error briefly in French."
                    fallback = "La compilation échoue sur une erreur de syntaxe. Regarde la console et la revue."
                case .success:
                    task = "Review this Swift exercise solution. Give 2–3 concise code review comments in French."
                    fallback = "La solution compile. Quelques remarques de lisibilité avant de valider."
                case .resolved:
                    task = "The Swift exercise is solved. Short French coach message: validation, one strength, one next-step challenge."
                    fallback = "Bien joué. Version propre et validée."
                case .writing, .hint:
                    return
                }
                appendCoachMessage(await callAI(task: task) ?? fallback)
            }
        } else {
            consoleLines = compilation.console
            annotations = []
            Task {
                isCoachThinking = true
                defer { isCoachThinking = false }
                await runAIReview(for: compilation.state)
            }
        }
    }

    func requestHint() {
        coachState = .hint
        feedbackSheetOpen = true
        feedbackTab = .review

        if dataSource == .demo {
            let index = min(chatThread.filter { $0.who == .coach }.count % CoachDemoData.hints.count, CoachDemoData.hints.count - 1)
            syncDemoConsole(for: .hint)
            appendCoachMessage(CoachDemoData.hints[index])
            return
        }

        consoleLines = [.init(kind: .cmd, text: "coach hint"), .init(kind: .out, text: "…")]

        Task {
            isCoachThinking = true
            defer { isCoachThinking = false }
            let fallback = progressiveHints.first ?? "Réfléchis à la structure de données optimale."
            let hint = await callAI(
                task: "Give one concise French hint for this Swift exercise without revealing the full solution. Return just the hint text, no JSON."
            ) ?? fallback
            progressiveHints.append(hint)
            consoleLines = [.init(kind: .cmd, text: "coach hint"), .init(kind: .out, text: hint)]
            appendCoachMessage(hint)
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
            isCoachThinking = true
            defer { isCoachThinking = false }

            if dataSource != .demo && looksLikeExerciseRequest(trimmed) {
                await generateExercise(from: trimmed)
                return
            }

            let fallback = localResponse(to: trimmed)
            appendCoachMessage(await callAI(
                task: "Answer the user's coaching message in French as a concise Swift coding coach. User message: \(trimmed)"
            ) ?? fallback)
        }
    }

    func appendCode(_ snippet: String) {
        replaceSelection(with: snippet)
        if coachState != .writing {
            coachState = .writing
            annotations = []
            consoleLines = [.init(kind: .out, text: "// prêt. lance la compilation quand tu veux.")]
        }
    }

    func moveCursor(by offset: Int) {
        let text = code as NSString
        let range = clampedRange(selectedRange, in: text)
        selectedRange = NSRange(location: max(0, min(text.length, range.location + offset)), length: 0)
    }

    func clearConsole() {
        consoleLines = [.init(kind: .out, text: "// console vidée")]
    }

    func deleteBackward() {
        let text = code as NSString
        let range = clampedRange(selectedRange, in: text)
        guard range.location > 0 || range.length > 0 else { return }

        if range.length > 0 {
            code = text.replacingCharacters(in: range, with: "")
            selectedRange = NSRange(location: range.location, length: 0)
        } else {
            let deletionRange = NSRange(location: range.location - 1, length: 1)
            code = text.replacingCharacters(in: deletionRange, with: "")
            selectedRange = NSRange(location: deletionRange.location, length: 0)
        }

        if coachState != .writing {
            coachState = .writing
            annotations = []
            consoleLines = [.init(kind: .out, text: "// prêt. lance la compilation quand tu veux.")]
        }
    }

    func applyKeyboardAction(_ action: CodeKeyboardAction) {
        switch action {
        case .insert(let text):
            appendCode(text)
        case .template(let template):
            applyTemplate(template)
        case .moveCursor(let offset):
            moveCursor(by: offset)
        case .deleteBackward:
            deleteBackward()
        }
    }

    // MARK: - AI review

    private func runAIReview(for state: CoachState) async {
        switch state {
        case .resolved:
            let msg = await callAI(
                task: "The Swift exercise is solved with assertions. Short French coach message: validate, one strength, one next challenge."
            ) ?? "Bien joué. Version propre et validée."
            appendCoachMessage(msg)

        case .error:
            let prompt = """
            Review this Swift code that failed to compile. Return ONLY JSON (no markdown):
            {"summary":"brief explanation in French","annotations":[{"line":1,"kind":"error","title":"Short title","body":"Explanation in French"}]}
            Keep line numbers accurate. Focus on the compile error.
            """
            await applyReviewJSON(await callAI(task: prompt),
                                  fallback: "La compilation échoue sur une erreur de syntaxe.")

        case .success:
            let prompt = """
            Review this correct Swift code solution. Return ONLY JSON (no markdown):
            {"summary":"brief summary in French","annotations":[{"line":1,"kind":"praise|nit|suggestion","title":"Short title","body":"Explanation in French"}]}
            Give 2–3 comments on code quality. Keep line numbers accurate.
            """
            await applyReviewJSON(await callAI(task: prompt),
                                  fallback: "La solution compile. Quelques remarques avant de valider.")

        case .writing, .hint:
            break
        }
    }

    private func replaceSelection(with replacement: String) {
        let text = code as NSString
        let range = clampedRange(selectedRange, in: text)
        code = text.replacingCharacters(in: range, with: replacement)
        selectedRange = NSRange(location: range.location + (replacement as NSString).length, length: 0)
    }

    private func applyTemplate(_ template: String) {
        let text = code as NSString
        let range = clampedRange(selectedRange, in: text)
        let selectedText = range.length > 0 ? text.substring(with: range) : "<#code#>"
        var expanded = template.replacingOccurrences(of: "[[selection]]", with: selectedText)
        var newSelection = NSRange(location: range.location + (expanded as NSString).length, length: 0)

        if let markerRange = expanded.range(of: #"\[\[cursor:.*?\]\]"#, options: .regularExpression) {
            let marker = String(expanded[markerRange])
            let placeholder = marker
                .replacingOccurrences(of: "[[cursor:", with: "")
                .replacingOccurrences(of: "]]", with: "")
            let nsExpanded = expanded as NSString
            let nsRange = nsExpanded.range(of: marker)
            expanded = nsExpanded.replacingCharacters(in: nsRange, with: placeholder)
            newSelection = NSRange(location: range.location + nsRange.location, length: (placeholder as NSString).length)
        } else if let markerRange = expanded.range(of: "[[cursor]]") {
            let nsExpanded = expanded as NSString
            let nsRange = nsExpanded.range(of: "[[cursor]]")
            expanded = nsExpanded.replacingCharacters(in: nsRange, with: "")
            newSelection = NSRange(location: range.location + nsRange.location, length: 0)
        }

        code = text.replacingCharacters(in: range, with: expanded)
        selectedRange = newSelection

        if coachState != .writing {
            coachState = .writing
            annotations = []
            consoleLines = [.init(kind: .out, text: "// prêt. lance la compilation quand tu veux.")]
        }
    }

    private func clampedRange(_ range: NSRange, in text: NSString) -> NSRange {
        let location = max(0, min(text.length, range.location))
        let maxLength = max(0, text.length - location)
        let length = max(0, min(maxLength, range.length))
        return NSRange(location: location, length: length)
    }

    private func applyReviewJSON(_ raw: String?, fallback: String) async {
        guard let raw else {
            appendCoachMessage(fallback)
            return
        }
        if let parsed = parseReviewJSON(raw) {
            annotations = parsed.annotations.compactMap { ann -> Annotation? in
                guard let kind = Annotation.Kind(rawValue: ann.kind) else { return nil }
                return Annotation(line: ann.line, kind: kind, title: ann.title, body: ann.body)
            }
            appendCoachMessage(parsed.summary)
        } else {
            appendCoachMessage(raw)
        }
    }

    // MARK: - Exercise generation

    private func looksLikeExerciseRequest(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = ["exercice", "exo", "exercise", "pratique", "entraînement", "entrainement",
                        "challenge", "algo", "algorithme", "problème", "probleme",
                        "dictionnaire", "optional", "protocol", "async", "tri", "recherche",
                        "tableau", "string", "struct", "class", "closure", "générique", "generique",
                        "swift", "fonction", "fonction", "récursif", "recursif"]
        return keywords.contains(where: { lower.contains($0) })
    }

    private func generateExercise(from userRequest: String) async {
        let prompt = """
        The user wants a Swift coding exercise: "\(userRequest)"

        Return ONLY valid JSON (no markdown, no explanation):
        {
          "id": "kebab-case-id",
          "topic": "topic in French",
          "difficulty": "Débutant|Intermédiaire|Avancé",
          "title": "Exercise title in French",
          "brief": "Full exercise description in French (2–4 sentences)",
          "constraints": ["constraint 1", "constraint 2"],
          "examples": [{"input": "...", "output": "...", "note": null}],
          "signature": "func name(_ param: Type) -> ReturnType",
          "starterCode": "func name(_ param: Type) -> ReturnType {\\n    // TODO: implémenter\\n    return []\\n}",
          "hints": ["hint 1 without spoiling", "hint 2", "hint 3"]
        }
        """

        guard let raw = await callAI(task: prompt) else {
            appendCoachMessage("Je n'ai pas pu générer l'exercice. Réessaie avec plus de détails.")
            return
        }

        if let ex = parseExerciseJSON(raw) {
            exercise = Exercise(
                id: ex.id,
                topic: ex.topic,
                difficulty: ex.difficulty,
                title: ex.title,
                brief: ex.brief,
                constraints: ex.constraints,
                examples: ex.examples.map { ExerciseExample(input: $0.input, output: $0.output, note: $0.note) },
                signature: ex.signature
            )
            code = ex.starterCode
            selectedRange = NSRange(location: ex.starterCode.count, length: 0)
            progressiveHints = ex.hints
            annotations = []
            coachState = .writing
            consoleLines = [.init(kind: .out, text: "// \(ex.id).swift prêt. Lance la compilation quand tu veux.")]
            appendCoachMessage("J'ai chargé « \(ex.title) ». Lance la compilation quand tu es prêt.")
        } else {
            appendCoachMessage(raw)
        }
    }

    // MARK: - JSON parsing

    private struct ReviewJSON: Decodable {
        let summary: String
        let annotations: [AnnotationJSON]
        struct AnnotationJSON: Decodable {
            let line: Int
            let kind: String
            let title: String
            let body: String
        }
    }

    private struct ExerciseJSON: Decodable {
        let id: String
        let topic: String
        let difficulty: String
        let title: String
        let brief: String
        let constraints: [String]
        let examples: [ExampleJSON]
        let signature: String
        let starterCode: String
        let hints: [String]
        struct ExampleJSON: Decodable {
            let input: String
            let output: String
            let note: String?
        }
    }

    private func parseReviewJSON(_ raw: String) -> ReviewJSON? {
        guard let data = extractJSON(from: raw).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReviewJSON.self, from: data)
    }

    private func parseExerciseJSON(_ raw: String) -> ExerciseJSON? {
        guard let data = extractJSON(from: raw).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ExerciseJSON.self, from: data)
    }

    private func extractJSON(from text: String) -> String {
        let stripped = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = stripped.firstIndex(of: "{"), let end = stripped.lastIndex(of: "}") {
            return String(stripped[start...end])
        }
        return stripped
    }

    // MARK: - Code evaluation (local, no compiler)

    private func evaluateCode(_ source: String) -> (state: CoachState, console: [ConsoleLine]) {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let filename = (exercise.id.isEmpty || exercise.id == "placeholder") ? "main" : exercise.id

        let opens = normalized.filter { $0 == "{" }.count
        let closes = normalized.filter { $0 == "}" }.count
        if opens != closes {
            return (.error, [
                .init(kind: .cmd, text: "swift run \(filename).swift"),
                .init(kind: .out, text: "Compiling \(filename).swift…"),
                .init(kind: .err, text: "error: unbalanced braces"),
                .init(kind: .err, text: "Build failed (1 error)"),
            ])
        }

        let lines = normalized.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("//") { continue }
            if (trimmed.hasPrefix("if ") || trimmed.hasPrefix("guard ")) &&
               !trimmed.hasSuffix("{") && !trimmed.hasSuffix(",") {
                let next = i + 1 < lines.count ? lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if !next.hasPrefix("{") && !next.hasPrefix("else") {
                    return (.error, [
                        .init(kind: .cmd, text: "swift run \(filename).swift"),
                        .init(kind: .out, text: "Compiling \(filename).swift…"),
                        .init(kind: .err, text: "\(filename).swift:\(i + 1): error: expected '{' after condition"),
                        .init(kind: .err, text: "Build failed (1 error)"),
                    ])
                }
            }
        }

        let ok: [ConsoleLine] = [
            .init(kind: .cmd, text: "swift run \(filename).swift"),
            .init(kind: .out, text: "Compiling \(filename).swift…"),
            .init(kind: .out, text: "Build complete!"),
            .init(kind: .ok, text: "Process exited with code 0"),
        ]

        if normalized.contains("assert(") { return (.resolved, ok) }
        return (.success, ok)
    }

    // MARK: - Demo helpers

    private func demoConsoleLines(for state: CoachState) -> [ConsoleLine] {
        switch state {
        case .error:    return CoachDemoData.consoleLinesError
        case .success:  return CoachDemoData.consoleLinesSuccess
        case .resolved: return CoachDemoData.consoleLinesResolved
        case .writing:  return [CoachDemoData.idleConsoleLine]
        case .hint:
            return [
                .init(kind: .cmd, text: "coach hint"),
                .init(kind: .out, text: progressiveHints.first ?? "Cherche le complément dans un dictionnaire.")
            ]
        }
    }

    private func demoAnnotations(for state: CoachState) -> [Annotation] {
        switch state {
        case .error:    return CoachDemoData.annotationsError
        case .success:  return CoachDemoData.annotationsSuccess
        default:        return []
        }
    }

    private func syncDemoConsole(for state: CoachState) {
        consoleLines = demoConsoleLines(for: state)
    }

    // MARK: - Helpers

    private func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    private func appendCoachMessage(_ text: String) {
        chatThread.append(CoachMessage(who: .coach, text: text, time: timeString()))
    }

    private func callAI(task: String) async -> String? {
        guard let aiResponder else { return nil }
        do {
            return try await aiResponder(task, code)
        } catch {
            consoleLines.append(.init(kind: .err, text: "coach ai: \(error.localizedDescription)"))
            return nil
        }
    }

    private func localResponse(to prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("indice") || lower.contains("help") || lower.contains("bloqu") {
            return progressiveHints.first ?? "Commence par chercher la bonne structure de données."
        }
        if lower.contains("error") || lower.contains("erreur") || lower.contains("compile") {
            return "Relance la compilation. Je pointerai la ligne fautive dans la revue."
        }
        if lower.contains("test") || lower.contains("assert") {
            return "Ajoute deux assertions minimales sur les cas de l'énoncé. Si elles passent, l'exercice est résolu."
        }
        return "Dis-moi sur quel exercice tu veux travailler, ou demande-moi un indice."
    }
}
