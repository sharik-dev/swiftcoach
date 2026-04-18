import SwiftUI

struct SwiftToolbarView: View {
    let onKey: (String) -> Void

    private let keys: [(label: String, value: String)] = [
        ("tab", "    "),
        ("{",   "{"),
        ("}",   "}"),
        ("(",   "("),
        (")",   ")"),
        ("[",   "["),
        ("]",   "]"),
        ("->",  "-> "),
        ("let", "let "),
        ("var", "var "),
        ("func","func "),
        (":",   ": "),
        (",",   ", "),
        ("?",   "?"),
        ("!",   "!"),
        ("\"",  "\""),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(keys, id: \.label) { key in
                    Button {
                        onKey(key.value)
                    } label: {
                        Text(key.label)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.scInk)
                            .frame(minWidth: 32)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.scBg3)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.scLineSoft, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.scBg2)
        .overlay(alignment: .top) {
            Divider().background(Color.scLineSoft)
        }
    }
}
