import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper

struct SyntaxEditorView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.spellCheckingType = .no
        tv.keyboardAppearance = .dark
        tv.indicatorStyle = .white
        tv.tintColor = UIColor(Color.scAccent2)
        tv.inputAccessoryView = CodeKeyboardBar(textView: tv)
        tv.attributedText = SyntaxHighlighter.highlight(text)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        guard tv.text != text else { return }
        let sel = tv.selectedRange
        tv.attributedText = SyntaxHighlighter.highlight(text)
        let cap = (tv.text as NSString).length
        tv.selectedRange = NSRange(location: min(sel.location, cap), length: 0)
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        private var isApplying = false

        init(text: Binding<String>) { _text = text }

        func textViewDidChange(_ tv: UITextView) {
            guard !isApplying else { return }
            isApplying = true
            defer { isApplying = false }

            text = tv.text
            let sel = tv.selectedRange
            tv.attributedText = SyntaxHighlighter.highlight(tv.text)
            let cap = (tv.text as NSString).length
            tv.selectedRange = NSRange(location: min(sel.location, cap), length: sel.length)
        }
    }
}

// MARK: - Syntax Highlighter

enum SyntaxHighlighter {

    private static let keywords: Set<String> = [
        "func", "var", "let", "if", "else", "for", "while", "return",
        "class", "struct", "enum", "protocol", "extension", "import",
        "guard", "switch", "case", "default", "break", "continue",
        "self", "super", "init", "deinit", "throw", "throws", "rethrows",
        "try", "catch", "async", "await", "actor", "in", "where",
        "as", "is", "nil", "true", "false", "override", "final",
        "static", "mutating", "inout", "lazy", "weak", "unowned",
        "private", "public", "internal", "open", "fileprivate",
        "typealias", "associatedtype", "some", "any",
        "get", "set", "willSet", "didSet", "defer", "repeat", "do", "new"
    ]

    static func highlight(_ source: String) -> NSAttributedString {
        let base: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(Color.scInk),
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ]
        let result = NSMutableAttributedString(string: source, attributes: base)
        var protected = IndexSet()

        // Comments and strings first — they define protected ranges
        colorize(result, #"//[^\n]*"#,            color: UIColor(Color.swCm),  protect: &protected)
        colorize(result, #"/\*[\s\S]*?\*/"#,      color: UIColor(Color.swCm),  protect: &protected)
        colorize(result, #""(?:[^"\\]|\\.)*""#,   color: UIColor(Color.swStr), protect: &protected)
        colorize(result, #"'(?:[^'\\]|\\.)*'"#,   color: UIColor(Color.swStr), protect: &protected)

        // Keywords (outside protected zones)
        applyKeywords(result, source, protected: protected)

        // Types: capitalized identifiers
        colorizeOutside(result, #"\b[A-Z][a-zA-Z0-9_]*\b"#,
                        color: UIColor(Color.swType), protected: protected)

        // Numbers
        colorizeOutside(result, #"\b\d+\.?\d*\b"#,
                        color: UIColor(Color.swNum), protected: protected)

        // Attributes (@something)
        colorizeOutside(result, #"@\w+"#,
                        color: UIColor(Color.swKw).withAlphaComponent(0.75), protected: protected)

        // Operators: -> ?? == != <= >=
        colorizeOutside(result, #"->|\.\.\.|\?\?|==|!=|<=|>="#,
                        color: UIColor(Color.swOp), protected: protected)

        return result
    }

    // Apply color + mark ranges as protected
    private static func colorize(
        _ attr: NSMutableAttributedString,
        _ pattern: String,
        color: UIColor,
        protect: inout IndexSet
    ) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return }
        let nsStr = attr.string
        let full = NSRange(location: 0, length: (nsStr as NSString).length)
        for m in re.matches(in: nsStr, range: full) {
            let r = m.range
            attr.addAttribute(.foregroundColor, value: color, range: r)
            protect.insert(integersIn: r.location ..< (r.location + r.length))
        }
    }

    // Apply color only outside protected ranges
    private static func colorizeOutside(
        _ attr: NSMutableAttributedString,
        _ pattern: String,
        color: UIColor,
        protected: IndexSet
    ) {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        let nsStr = attr.string
        let full = NSRange(location: 0, length: (nsStr as NSString).length)
        for m in re.matches(in: nsStr, range: full) {
            let r = m.range
            guard r.length > 0 else { continue }
            guard !protected.intersects(integersIn: r.location ..< (r.location + r.length)) else { continue }
            attr.addAttribute(.foregroundColor, value: color, range: r)
        }
    }

    private static func applyKeywords(
        _ attr: NSMutableAttributedString,
        _ source: String,
        protected: IndexSet
    ) {
        guard let re = try? NSRegularExpression(pattern: #"\b([a-z_][a-zA-Z0-9_]*)\b"#) else { return }
        let ns = source as NSString
        let full = NSRange(location: 0, length: ns.length)
        for m in re.matches(in: source, range: full) {
            let r = m.range
            guard !protected.intersects(integersIn: r.location ..< (r.location + r.length)) else { continue }
            let word = ns.substring(with: r)
            if keywords.contains(word) {
                attr.addAttribute(.foregroundColor, value: UIColor(Color.swKw), range: r)
            }
        }
    }
}

// MARK: - Custom Code Keyboard Bar

final class CodeKeyboardBar: UIInputView {
    private weak var textView: UITextView?

    init(textView: UITextView) {
        self.textView = textView
        let w = UIScreen.main.bounds.width
        super.init(frame: CGRect(x: 0, y: 0, width: w, height: 90), inputViewStyle: .keyboard)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(red: 0.105, green: 0.105, blue: 0.14, alpha: 1)

        // Row 1: navigation + tab + delete
        let navItems: [(String, () -> Void)] = [
            ("◀",  { self.moveCursor(-1) }),
            ("▶",  { self.moveCursor(1) }),
            ("▲",  { self.moveLine(-1) }),
            ("▼",  { self.moveLine(1) }),
            ("⇥",  { self.insert("    ") }),
            ("⌫",  { self.deleteBack() }),
            ("↵",  { self.insert("\n") }),
        ]

        // Row 2: code symbols (scrollable)
        let codeItems: [(String, () -> Void)] = [
            ("{",  { self.insertPair("{", "}") }),
            ("}",  { self.insert("}") }),
            ("(",  { self.insertPair("(", ")") }),
            (")",  { self.insert(")") }),
            ("[",  { self.insertPair("[", "]") }),
            ("]",  { self.insert("]") }),
            ("\"", { self.insertPair("\"", "\"") }),
            ("'",  { self.insertPair("'", "'") }),
            (":",  { self.insert(": ") }),
            (";",  { self.insert(";") }),
            (".",  { self.insert(".") }),
            (",",  { self.insert(", ") }),
            ("=",  { self.insert(" = ") }),
            ("->", { self.insert(" -> ") }),
            ("??", { self.insert(" ?? ") }),
            ("!",  { self.insert("!") }),
            ("?",  { self.insert("?") }),
            ("_",  { self.insert("_") }),
            ("@",  { self.insert("@") }),
            ("#",  { self.insert("#") }),
            ("//", { self.insert("// ") }),
            ("+",  { self.insert(" + ") }),
            ("-",  { self.insert(" - ") }),
            ("*",  { self.insert(" * ") }),
            ("/",  { self.insert(" / ") }),
        ]

        let row1 = makeScrollRow(navItems, fixedWidth: true)
        let row2 = makeScrollRow(codeItems, fixedWidth: false)

        let stack = UIStackView(arrangedSubviews: [row1, row2])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
        ])
    }

    private func makeScrollRow(_ items: [(String, () -> Void)], fixedWidth: Bool) -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        for (title, action) in items {
            let btn = makeKey(title: title, wide: title.count > 1 && fixedWidth, action: action)
            stack.addArrangedSubview(btn)
        }

        return scroll
    }

    private func makeKey(title: String, wide: Bool, action: @escaping () -> Void) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(UIColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1), for: .normal)
        btn.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.27, alpha: 1)
        btn.layer.cornerRadius = 7
        btn.layer.masksToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: wide ? 14 : 10, bottom: 0, right: wide ? 14 : 10)

        if wide {
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        }

        let handler = UIAction { _ in action() }
        btn.addAction(handler, for: .touchUpInside)
        return btn
    }

    // MARK: - Actions

    private func moveCursor(_ offset: Int) {
        guard let tv = textView, let range = tv.selectedTextRange else { return }
        let anchor = offset < 0 ? range.start : range.end
        if let pos = tv.position(from: anchor, offset: offset) {
            tv.selectedTextRange = tv.textRange(from: pos, to: pos)
        }
        haptic()
    }

    private func moveLine(_ direction: Int) {
        guard let tv = textView,
              let range = tv.selectedTextRange,
              let pos = tv.position(from: range.start, in: direction > 0 ? .down : .up, offset: 1) else { return }
        tv.selectedTextRange = tv.textRange(from: pos, to: pos)
        haptic()
    }

    private func insert(_ text: String) {
        textView?.insertText(text)
        haptic()
    }

    private func insertPair(_ open: String, _ close: String) {
        guard let tv = textView else { return }
        tv.insertText(open + close)
        if let sel = tv.selectedTextRange,
           let pos = tv.position(from: sel.start, offset: -close.utf16.count) {
            tv.selectedTextRange = tv.textRange(from: pos, to: pos)
        }
        haptic()
    }

    private func deleteBack() {
        textView?.deleteBackward()
        haptic()
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
