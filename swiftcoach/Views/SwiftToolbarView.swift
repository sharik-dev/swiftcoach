import SwiftUI

enum CodeKeyboardAction {
    case insert(String)
    case template(String)
    case moveCursor(Int)
    case deleteBackward
}

struct SwiftToolbarView: View {
    let onAction: (CodeKeyboardAction) -> Void
    @State private var isExpanded = false

    private let compactKeys: [(label: String, action: CodeKeyboardAction)] = [
        ("←", .moveCursor(-1)),
        ("→", .moveCursor(1)),
        ("if {}", .template("if [[cursor:condition]] {\n    [[selection]]\n}")),
        ("func {}", .template("func [[cursor:name]]() {\n    [[selection]]\n}")),
        ("{ }", .template("{[[cursor]]}")),
        ("( )", .template("([[cursor]])")),
        ("↩", .insert("\n")),
        ("tab", .insert("    ")),
    ]

    private let rows: [[(label: String, action: CodeKeyboardAction)]] = [
        [
            ("←", .moveCursor(-1)), ("→", .moveCursor(1)), ("{ }", .template("{[[cursor]]}")), ("( )", .template("([[cursor]])")),
            ("[ ]", .template("[[cursor]]")), ("\" \"", .template("\"[[cursor]]\"")), ("->", .insert("-> ")), ("=", .insert(" = "))
        ],
        [
            ("if {}", .template("if [[cursor:condition]] {\n    [[selection]]\n}")),
            ("guard let", .template("guard let [[cursor:value]] = [[selection]] else {\n    return\n}")),
            ("func {}", .template("func [[cursor:name]]() {\n    [[selection]]\n}")),
            ("for in", .template("for [[cursor:item]] in [[selection]] {\n    <#code#>\n}"))
        ],
        [
            ("let", .insert("let ")), ("var", .insert("var ")), ("return", .insert("return ")), ("guard", .insert("guard ")),
            ("nil", .insert("nil")), ("self", .insert("self")), ("//", .insert("// ")), ("↩", .insert("\n"))
        ],
        [
            ("tab", .insert("    ")), (":", .insert(": ")), (",", .insert(", ")), (".", .insert(".")),
            ("?", .insert("?")), ("!", .insert("!")), ("&&", .insert(" && ")), ("||", .insert(" || "))
        ]
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .font(.system(size: 13))
                        Text(isExpanded ? "Clavier code" : "Déplier")
                            .font(.system(size: 11).weight(.semibold))
                    }
                    .foregroundStyle(isExpanded ? Color.black : Color.scInk2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isExpanded ? Color.scAccent : Color.scBg3)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Text("Swift")
                        .font(.system(size: 10, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.scAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.scAccent.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    onAction(.deleteBackward)
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 13).weight(.semibold))
                        .foregroundStyle(Color.scDanger)
                        .frame(width: 34, height: 34)
                        .background(Color.scDanger.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(row, id: \.label) { key in
                                    keyButton(label: key.label, action: key.action)
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.bottom, 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(compactKeys, id: \.label) { key in
                            keyButton(label: key.label, action: key.action)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.scBg2)
        .overlay(alignment: .top) {
            Divider().background(Color.scLineSoft)
        }
    }

    private func keyButton(label: String, action: CodeKeyboardAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.scInk)
                .frame(minWidth: 34)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color.scBg3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.scLineSoft, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
