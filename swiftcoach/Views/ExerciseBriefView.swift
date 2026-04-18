import SwiftUI

struct ExerciseBriefView: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pills + id
            HStack(spacing: 8) {
                SCPill(label: exercise.topic, tone: .warm)
                SCPill(label: exercise.difficulty, tone: .cyan)
                Spacer()
                Text("#\(exercise.id)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.scInk4)
            }
            .padding(.bottom, 10)

            Text(exercise.title)
                .font(.system(size: 18).weight(.semibold))
                .foregroundStyle(Color.scInk)
                .padding(.bottom, 8)

            Text(exercise.brief)
                .font(.system(size: 13))
                .foregroundStyle(Color.scInk2)
                .lineSpacing(4)
                .padding(.bottom, 14)

            // Constraints
            Text("CONTRAINTES")
                .font(.system(size: 10).weight(.semibold))
                .foregroundStyle(Color.scInk3)
                .kerning(1.2)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(exercise.constraints, id: \.self) { constraint in
                    HStack(spacing: 8) {
                        Text("›")
                            .foregroundStyle(Color.scAccent)
                            .font(.system(size: 12, design: .monospaced).weight(.bold))
                        Text(constraint)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.scInk2)
                    }
                }
            }
            .padding(.bottom, 14)

            // Examples
            Text("EXEMPLES")
                .font(.system(size: 10).weight(.semibold))
                .foregroundStyle(Color.scInk3)
                .kerning(1.2)
                .padding(.bottom, 6)

            VStack(spacing: 8) {
                ForEach(Array(exercise.examples.enumerated()), id: \.offset) { _, ex in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("in  ")
                                .foregroundStyle(Color.scInk4)
                            Text(ex.input)
                                .foregroundStyle(Color.scInk2)
                        }
                        HStack(spacing: 6) {
                            Text("out ")
                                .foregroundStyle(Color.scInk4)
                            Text(ex.output)
                                .foregroundStyle(Color.scAccent4)
                        }
                        if let note = ex.note {
                            Text("// \(note)")
                                .foregroundStyle(Color.scInk4)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.scShell)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.scLineSoft, lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.scBg2, Color(hex: "181820")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.scLineSoft, lineWidth: 1)
        )
    }
}

// MARK: - Pill component

enum SCPillTone { case warm, cyan, green, red, neutral }

struct SCPill: View {
    let label: String
    let tone: SCPillTone

    private var bg: Color {
        switch tone {
        case .warm:    return Color(hex: "d48247").opacity(0.12)
        case .cyan:    return Color(hex: "5ac8e0").opacity(0.10)
        case .green:   return Color(hex: "78c882").opacity(0.10)
        case .red:     return Color(hex: "d0503c").opacity(0.10)
        case .neutral: return Color.scBg4
        }
    }

    private var fg: Color {
        switch tone {
        case .warm:    return Color(hex: "d48247")
        case .cyan:    return Color(hex: "5ac8e0")
        case .green:   return Color(hex: "78c882")
        case .red:     return Color(hex: "d0503c")
        case .neutral: return Color.scInk2
        }
    }

    private var border: Color {
        switch tone {
        case .warm:    return Color(hex: "d48247").opacity(0.30)
        case .cyan:    return Color(hex: "5ac8e0").opacity(0.25)
        case .green:   return Color(hex: "78c882").opacity(0.25)
        case .red:     return Color(hex: "d0503c").opacity(0.30)
        case .neutral: return Color.scLine
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11).weight(.medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }
}
