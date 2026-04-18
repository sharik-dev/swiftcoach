import SwiftUI
import UIKit
import UIKit

// MARK: - Root workspace

struct AssistantWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel
    @StateObject private var editorViewModel: EditorViewModel
    @StateObject private var coachVM = CoachViewModel()
    @Environment(\.horizontalSizeClass) private var hSize

    init(appState: AppState, aiViewModel: AIViewModel) {
        _editorViewModel = StateObject(wrappedValue: EditorViewModel(aiViewModel: aiViewModel, appState: appState))
        _coachVM = StateObject(
            wrappedValue: CoachViewModel(
                dataSource: appState.exerciseDataSource,
                aiResponder: { task, codeContext in
                    try await aiViewModel.requestResponse(
                        task: task,
                        codeContext: codeContext,
                        provider: appState.selectedProvider,
                        backendBaseURL: appState.backendBaseURL,
                        languageHint: "French"
                    )
                }
            )
        )
    }

    var body: some View {
        if hSize == .regular {
            DesktopLayout(coachVM: coachVM)
        } else {
            MobileLayout(coachVM: coachVM)
        }
    }
}

// MARK: - Desktop (iPad)

private struct DesktopLayout: View {
    @ObservedObject var coachVM: CoachViewModel
    @State private var annotationStyle: CodeEditorView.AnnotationStyle = .inline
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar toggle + sidebar
            if showSidebar {
                CoachSidebarView(vm: coachVM)
                    .frame(width: 300)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .overlay(alignment: .trailing) {
                        Divider().background(Color.scLineSoft)
                    }
            }

            // Center column
            VStack(spacing: 0) {
                // Top toolbar
                DesktopToolbar(
                    coachVM: coachVM,
                    annotationStyle: $annotationStyle,
                    showSidebar: $showSidebar
                )

                ScrollView {
                    ExerciseBriefView(exercise: coachVM.exercise)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                .frame(maxHeight: 260)

                // Editor + console
                VStack(spacing: 0) {
                    EditorTabBar(coachVM: coachVM)

                    if coachVM.coachState == .writing {
                        EditableCodeEditor(coachVM: coachVM)
                            .frame(maxHeight: .infinity)
                    } else {
                        CodeEditorView(
                            code: coachVM.code,
                            annotations: coachVM.annotations,
                            annotationStyle: annotationStyle
                        )
                        .frame(maxHeight: .infinity)
                    }

                    EditorActionBar(coachVM: coachVM)
                    ConsolePanelView(lines: coachVM.consoleLines, onClear: coachVM.clearConsole)
                        .frame(height: 150)
                }
                .background(Color.scBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.scLineSoft, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.scShell)

            // Feedback side panel
            VStack(spacing: 0) {
                FeedbackPanelView(coachVM: coachVM)
            }
            .frame(width: 340)
            .background(Color(hex: "14141a"))
            .overlay(alignment: .leading) {
                Divider().background(Color.scLineSoft)
            }
        }
        .background(Color.scShell)
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
    }
}

// MARK: - Desktop toolbar

private struct DesktopToolbar: View {
    @ObservedObject var coachVM: CoachViewModel
    @Binding var annotationStyle: CodeEditorView.AnnotationStyle
    @Binding var showSidebar: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Sidebar toggle
            Button {
                withAnimation { showSidebar.toggle() }
            } label: {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundStyle(showSidebar ? Color.scAccent : Color.scInk3)
                    .frame(width: 30, height: 30)
                    .background(showSidebar ? Color.scAccent.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 18)
                .background(Color.scLineSoft)

            // Exercise info
            HStack(spacing: 6) {
                Text("\(coachVM.exercise.id).swift")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.scInk2)
                Circle()
                    .fill(coachVM.buildStatusColor)
                    .frame(width: 6, height: 6)
                Text(coachVM.buildStatusLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(coachVM.buildStatusColor)
            }

            Spacer()

            // Annotation style
            HStack(spacing: 2) {
                ForEach(
                    [(CodeEditorView.AnnotationStyle.gutter, "gutter"),
                     (.inline, "inline"),
                     (.margin, "marge")],
                    id: \.1
                ) { style, label in
                    Button(label) { annotationStyle = style }
                        .font(.system(size: 11).weight(.medium))
                        .foregroundStyle(annotationStyle == style ? Color.black : Color.scInk2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(annotationStyle == style ? Color.scInk : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.scBg3)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.scLine, lineWidth: 1))

            Divider()
                .frame(height: 18)
                .background(Color.scLineSoft)

            // State picker
            Menu {
                ForEach(CoachState.allCases, id: \.rawValue) { state in
                    Button(state.rawValue) { coachVM.setState(state) }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 12))
                    Text(coachVM.coachState.rawValue)
                        .font(.system(size: 11).weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundStyle(Color.scInk2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.scBg3)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.scLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

// MARK: - Mobile (iPhone)

private struct MobileLayout: View {
    @ObservedObject var coachVM: CoachViewModel
    @State private var showCoachSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            MobileHeader(coachVM: coachVM, onCoach: { showCoachSheet = true })

            // Brief (collapsible)
            MobileBriefCard(coachVM: coachVM)

            // File bar + state indicator
            MobileFileBar(coachVM: coachVM)

            // Code area: editable on writing state, annotated view otherwise
            if coachVM.coachState == .writing {
                EditableCodeEditor(coachVM: coachVM)
            } else {
                CodeEditorView(
                    code: coachVM.code,
                    annotations: coachVM.annotations,
                    annotationStyle: .inline
                )
                .background(Color.scBg)
            }

            // Swift toolbar — always above feedback
            SwiftToolbarView(onAction: coachVM.applyKeyboardAction)

            // Feedback section (inline, pushes content up)
            MobileInlineFeedback(coachVM: coachVM)
        }
        .background(Color.scBg)
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack {
                CoachSidebarView(vm: coachVM)
                    .navigationTitle("Swift Coach")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { showCoachSheet = false }
                                .foregroundStyle(Color.scAccent)
                        }
                    }
            }
            .background(Color(hex: "14141a"))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Writable editor

private struct EditableCodeEditor: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        IDETextView(text: $coachVM.code, selectedRange: $coachVM.selectedRange)
            .background(Color.scBg)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }
}

private struct IDETextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = UIColor(Color.scInk)
        view.tintColor = UIColor(Color.scAccent)
        view.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.keyboardDismissMode = .interactive
        view.textContainerInset = UIEdgeInsets(top: 14, left: 0, bottom: 24, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.text = text
        view.selectedRange = selectedRange
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }
        if uiView.window != nil, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var selectedRange: NSRange

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            _text = text
            _selectedRange = selectedRange
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            selectedRange = textView.selectedRange
        }
    }
}

// MARK: - Mobile inline feedback (pushes layout, no overlay)

private struct MobileInlineFeedback: View {
    @ObservedObject var coachVM: CoachViewModel

    private var summaryIcon: String {
        switch coachVM.coachState {
        case .error:    return "xmark"
        case .success, .resolved: return "checkmark"
        case .hint:     return "lightbulb"
        case .writing:  return "ellipsis"
        }
    }

    private var summaryColor: Color {
        switch coachVM.coachState {
        case .error:    return .scDanger
        case .success, .resolved: return .scOk
        case .hint:     return .scAccent5
        case .writing:  return .scInk4
        }
    }

    private var summaryLabel: String {
        switch coachVM.coachState {
        case .error:    return "Build échoué"
        case .success:  return "Build OK · \(coachVM.annotations.count) remarques"
        case .resolved: return "Exercice résolu ✓"
        case .hint:     return "Indice disponible"
        case .writing:  return "Prêt à compiler"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    coachVM.feedbackSheetOpen.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Status icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(summaryColor)
                            .frame(width: 30, height: 30)
                        Image(systemName: summaryIcon)
                            .font(.system(size: 12).weight(.bold))
                            .foregroundStyle(.black)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("FEEDBACK COACH")
                            .font(.system(size: 9).weight(.semibold))
                            .foregroundStyle(Color.scInk3)
                            .kerning(1.1)
                        Text(summaryLabel)
                            .font(.system(size: 13).weight(.semibold))
                            .foregroundStyle(Color.scInk)
                    }

                    Spacer()

                    Image(systemName: coachVM.feedbackSheetOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11).weight(.medium))
                        .foregroundStyle(Color.scInk3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Collapsible content
            if coachVM.feedbackSheetOpen {
                FeedbackPanelView(coachVM: coachVM)
                .frame(height: 260)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(hex: "14141a"))
        .overlay(alignment: .top) {
            Divider().background(Color.scLine)
        }
    }
}

// MARK: - Shared components

private struct MobileHeader: View {
    @ObservedObject var coachVM: CoachViewModel
    let onCoach: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Coach button
            Button(action: onCoach) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(colors: [Color.scAccent, Color.scAccent3],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("SC")
                            .font(.system(size: 8, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.black)
                    }
                    .frame(width: 22, height: 22)
                    Text("Coach")
                        .font(.system(size: 11).weight(.semibold))
                        .foregroundStyle(Color.scAccent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.scAccent.opacity(0.10))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.scAccent.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            // Exercise metadata
            VStack(alignment: .trailing, spacing: 1) {
                Text(coachVM.exercise.title)
                    .font(.system(size: 12).weight(.semibold))
                    .foregroundStyle(Color.scInk)
                    .lineLimit(1)
                Text("\(coachVM.exercise.topic) · \(coachVM.exercise.difficulty)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.scInk3)
            }

            // Hint button
            Button {
                coachVM.requestHint()
            } label: {
                Image(systemName: "lightbulb")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.scAccent5)
                    .frame(width: 32, height: 32)
                    .background(Color.scAccent5.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

private struct MobileBriefCard: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coachVM.briefCollapsed.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 6) {
                        Text("ÉNONCÉ")
                            .font(.system(size: 9).weight(.bold))
                            .foregroundStyle(Color.scAccent)
                            .kerning(1.2)
                        SCPill(label: coachVM.exercise.topic, tone: .warm)
                    }
                    Spacer()
                    Image(systemName: coachVM.briefCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10).weight(.medium))
                        .foregroundStyle(Color.scInk3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if !coachVM.briefCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(coachVM.exercise.title)
                        .font(.system(size: 14).weight(.semibold))
                        .foregroundStyle(Color.scInk)

                    Text(coachVM.exercise.brief)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.scInk2)
                        .lineSpacing(3)
                        .lineLimit(3)

                    if let ex = coachVM.exercise.examples.first {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("in").foregroundStyle(Color.scInk4)
                                Text(ex.input.prefix(20) + "…").foregroundStyle(Color.scInk2)
                            }
                            HStack(spacing: 4) {
                                Text("→").foregroundStyle(Color.scInk4)
                                Text(ex.output).foregroundStyle(Color.scAccent4)
                            }
                        }
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(hex: "181820"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

private struct MobileFileBar: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        HStack(spacing: 10) {
            // File name + status
            HStack(spacing: 6) {
                Text("\(coachVM.exercise.id).swift")
                    .font(.system(size: 11, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.scInk2)
                Circle()
                    .fill(coachVM.buildStatusColor)
                    .frame(width: 5, height: 5)
            }

            Spacer()

            // Line count
            Text("\(coachVM.code.components(separatedBy: "\n").count) ln")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.scInk4)

            // Run button
            Button {
                coachVM.run()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("Compiler")
                        .font(.system(size: 11).weight(.bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.scAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // State picker (compact)
            Menu {
                ForEach(CoachState.allCases, id: \.rawValue) { state in
                    Button(state.rawValue) { coachVM.setState(state) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.scInk3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

// MARK: - Editor tab bar + action bar (desktop shared)

private struct EditorTabBar: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.scAccent)
                    .frame(width: 6, height: 6)
                Text("\(coachVM.exercise.id).swift")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.scInk)
                Text("×")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.scInk4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.scBg)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.scAccent)
                    .frame(height: 2)
            }

            Spacer()

            Text("Swift 5.10 · UTF-8")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.scInk4)
                .padding(.trailing, 12)
        }
        .frame(height: 34)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

private struct EditorActionBar: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                coachVM.run()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("Compiler & exécuter")
                        .font(.system(size: 12).weight(.semibold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.scAccent)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)

            Button {
                coachVM.requestHint()
            } label: {
                Text("Demander un indice")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.scInk2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color.scLine, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 14) {
                Text("\(coachVM.code.components(separatedBy: "\n").count) lignes")
                HStack(spacing: 4) {
                    Circle()
                        .fill(coachVM.buildStatusColor)
                        .frame(width: 6, height: 6)
                    Text(coachVM.buildStatusLabel)
                }
                .foregroundStyle(coachVM.buildStatusColor)
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.scInk4)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .top) {
            Divider().background(Color.scLineSoft)
        }
    }
}
