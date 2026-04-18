import SwiftUI

struct AssistantWorkspaceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var aiViewModel: AIViewModel
    @StateObject private var editorViewModel: EditorViewModel
    @StateObject private var coachVM = CoachViewModel()
    @Environment(\.horizontalSizeClass) private var hSize

    init(appState: AppState, aiViewModel: AIViewModel) {
        _editorViewModel = StateObject(wrappedValue: EditorViewModel(aiViewModel: aiViewModel, appState: appState))
    }

    var body: some View {
        if hSize == .regular {
            DesktopLayout(coachVM: coachVM)
        } else {
            MobileLayout(coachVM: coachVM)
        }
    }
}

// MARK: - Desktop (iPad / Mac)

private struct DesktopLayout: View {
    @ObservedObject var coachVM: CoachViewModel
    @State private var annotationStyle: CodeEditorView.AnnotationStyle = .inline
    @State private var feedbackPosition: FeedbackPosition = .right

    enum FeedbackPosition { case right, bottom, overlay }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            CoachSidebarView(vm: coachVM)
                .frame(width: 300)
                .overlay(alignment: .trailing) {
                    Divider().background(Color.scLineSoft)
                }

            // Center: editor + console
            VStack(spacing: 0) {
                ExerciseBriefView(exercise: coachVM.exercise)
                    .padding(16)

                // Editor card
                VStack(spacing: 0) {
                    EditorTabBar(coachVM: coachVM)
                    CodeEditorView(
                        code: coachVM.code,
                        annotations: coachVM.annotations,
                        annotationStyle: annotationStyle
                    )
                    EditorActionBar(coachVM: coachVM)
                    ConsolePanelView(lines: coachVM.consoleLines)
                        .frame(height: 160)
                }
                .background(Color.scBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.scLineSoft, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color.scShell)

            // Feedback panel
            if feedbackPosition == .right {
                VStack(spacing: 0) {
                    FeedbackPanelView(
                        state: coachVM.coachState,
                        annotations: coachVM.annotations,
                        tab: $coachVM.feedbackTab,
                        onHint: coachVM.requestHint
                    )
                }
                .frame(width: 360)
                .background(Color(hex: "14141a"))
                .overlay(alignment: .leading) {
                    Divider().background(Color.scLineSoft)
                }
            }
        }
        .background(Color.scShell)
        .overlay(alignment: .bottomLeading) {
            StatePickerView(coachVM: coachVM)
                .padding(16)
        }
    }
}

// MARK: - Mobile (iPhone)

private struct MobileLayout: View {
    @ObservedObject var coachVM: CoachViewModel
    @State private var showCoachSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Navigation header
                MobileHeader(coachVM: coachVM, onCoach: { showCoachSheet = true })

                // Brief (collapsible)
                MobileBriefCard(coachVM: coachVM)

                // File bar
                MobileFileBar(coachVM: coachVM)

                // Code editor
                CodeEditorView(
                    code: coachVM.code,
                    annotations: coachVM.annotations,
                    annotationStyle: .inline
                )
                .background(Color.scBg)

                // Swift toolbar
                SwiftToolbarView(onKey: coachVM.appendCode)
            }
            .background(Color.scBg)

            // Feedback bottom sheet
            MobileFeedbackSheet(coachVM: coachVM)
        }
        .background(Color.scBg)
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack {
                CoachSidebarView(vm: coachVM)
                    .navigationTitle("Swift Coach")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("OK") { showCoachSheet = false }
                                .foregroundStyle(Color.scAccent)
                        }
                    }
            }
            .background(Color(hex: "14141a"))
        }
    }
}

// MARK: - Shared sub-components

private struct MobileHeader: View {
    @ObservedObject var coachVM: CoachViewModel
    let onCoach: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCoach) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color.scAccent, Color.scAccent3],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("SC")
                        .font(.system(size: 9, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.black)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(coachVM.exercise.title)
                    .font(.system(size: 13).weight(.semibold))
                    .foregroundStyle(Color.scInk)
                    .lineLimit(1)
                Text("\(coachVM.exercise.topic) · \(coachVM.exercise.difficulty)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.scInk3)
            }

            Spacer()

            Button("indice") {
                coachVM.requestHint()
            }
            .font(.system(size: 11).weight(.semibold))
            .foregroundStyle(Color(hex: "d48247"))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color(hex: "d48247").opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "d48247").opacity(0.30), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coachVM.briefCollapsed.toggle()
                }
            } label: {
                HStack {
                    Text("ÉNONCÉ")
                        .font(.system(size: 10).weight(.bold))
                        .foregroundStyle(Color.scAccent)
                        .kerning(1.2)
                    Spacer()
                    Text(coachVM.briefCollapsed ? "déployer" : "réduire")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.scInk4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.scInk3)
                        .rotationEffect(coachVM.briefCollapsed ? .degrees(-90) : .zero)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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

                    // First example
                    if let ex = coachVM.exercise.examples.first {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("in  ").foregroundStyle(Color.scInk4)
                                Text(ex.input).foregroundStyle(Color.scInk2)
                            }
                            HStack(spacing: 6) {
                                Text("out ").foregroundStyle(Color.scInk4)
                                Text(ex.output).foregroundStyle(Color.scAccent4)
                            }
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.scShell)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.scLineSoft, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
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
        HStack(spacing: 8) {
            Text("twosum.swift")
                .font(.system(size: 10, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.scAccent)
            Text("·")
                .foregroundStyle(Color.scInk4)
            Text("\(coachVM.code.components(separatedBy: "\n").count) ln")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.scInk4)
            Spacer()
            Button {
                coachVM.run()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text("RUN")
                        .font(.system(size: 10).weight(.bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.scAccent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "14141a"))
        .overlay(alignment: .bottom) {
            Divider().background(Color.scLineSoft)
        }
    }
}

private struct MobileFeedbackSheet: View {
    @ObservedObject var coachVM: CoachViewModel

    private var summary: (color: Color, label: String, icon: String) {
        switch coachVM.coachState {
        case .error:    return (.scDanger, "Build échoué", "xmark")
        case .success:  return (.scOk, "Build OK · \(coachVM.annotations.count) remarques", "checkmark")
        case .resolved: return (.scOk, "Exercice résolu", "checkmark")
        case .hint:     return (.scAccent5, "Indice disponible", "questionmark")
        case .writing:  return (.scInk3, "En attente d'exécution", "circle.fill")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle + toggle row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    coachVM.feedbackSheetOpen.toggle()
                }
            } label: {
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color.scLine)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(summary.color)
                                .frame(width: 28, height: 28)
                            Image(systemName: summary.icon)
                                .font(.system(size: 12).weight(.bold))
                                .foregroundStyle(Color.black)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("FEEDBACK COACH")
                                .font(.system(size: 9).weight(.semibold))
                                .foregroundStyle(Color.scInk3)
                                .kerning(1.2)
                            Text(summary.label)
                                .font(.system(size: 13).weight(.semibold))
                                .foregroundStyle(Color.scInk)
                        }

                        Spacer()

                        Image(systemName: coachVM.feedbackSheetOpen ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.scInk3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .buttonStyle(.plain)

            // Feedback content (shown when open)
            if coachVM.feedbackSheetOpen {
                FeedbackPanelView(
                    state: coachVM.coachState,
                    annotations: coachVM.annotations,
                    tab: $coachVM.feedbackTab,
                    onHint: coachVM.requestHint
                )
                .frame(height: 300)
            }
        }
        .background(Color(hex: "14141a"))
        .clipShape(RoundedRectangle(cornerRadius: coachVM.feedbackSheetOpen ? 14 : 0, style: .continuous))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: coachVM.feedbackSheetOpen ? 14 : 0)
                .strokeBorder(Color.scLine, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 30, y: -10)
    }
}

// MARK: - Editor tab bar + action bar

private struct EditorTabBar: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.scAccent)
                    .frame(width: 6, height: 6)
                Text("twosum.swift")
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
            .overlay(
                HStack {
                    Divider().background(Color.scLineSoft)
                    Spacer()
                    Divider().background(Color.scLineSoft)
                }
            )

            Spacer()

            Text("Swift 5.10 · UTF-8 · LF")
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

            Button("Demander un indice") {
                coachVM.requestHint()
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.scInk2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.scLine, lineWidth: 1)
            )

            Spacer()

            HStack(spacing: 14) {
                Text("Ln 4, Col 29")
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

// MARK: - State picker overlay (desktop)

private struct StatePickerView: View {
    @ObservedObject var coachVM: CoachViewModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CoachState.allCases, id: \.rawValue) { state in
                Button {
                    coachVM.setState(state)
                } label: {
                    Text(state.rawValue)
                        .font(.system(size: 11).weight(.medium))
                        .foregroundStyle(coachVM.coachState == state ? Color.black : Color.scInk2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(coachVM.coachState == state ? Color.scInk : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.scLine, lineWidth: 1))
    }
}
