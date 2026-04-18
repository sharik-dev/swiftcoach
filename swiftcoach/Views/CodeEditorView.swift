import SwiftUI

// MARK: - Swift Syntax Highlighter

private let swiftKeywords: Set<String> = [
    "func","var","let","return","if","else","for","in","while","guard","switch","case","default",
    "struct","class","enum","protocol","extension","import","public","private","internal","fileprivate",
    "static","final","init","self","Self","throws","throw","try","as","is","nil","true","false",
    "async","await","do","catch","defer","break","continue","where","typealias","inout","mutating","open"
]

private let swiftTypes: Set<String> = [
    "Int","String","Double","Float","Bool","Array","Dictionary","Set","Any","AnyObject","Void",
    "Character","Optional","Result","Error","Never","UInt","Int64","Int32"
]

func highlightSwift(_ line: String) -> AttributedString {
    var result = AttributedString()
    var i = line.startIndex

    while i < line.endIndex {
        let c = line[i]

        // Line comment
        if c == "/" && line.index(after: i) < line.endIndex && line[line.index(after: i)] == "/" {
            var part = AttributedString(String(line[i...]))
            part.foregroundColor = .swCm
            result += part
            break
        }

        // String literal
        if c == "\"" {
            var j = line.index(after: i)
            while j < line.endIndex && line[j] != "\"" {
                if line[j] == "\\" && line.index(after: j) < line.endIndex {
                    j = line.index(j, offsetBy: 2)
                } else {
                    j = line.index(after: j)
                }
            }
            if j < line.endIndex { j = line.index(after: j) }
            var part = AttributedString(String(line[i..<j]))
            part.foregroundColor = .swStr
            result += part
            i = j
            continue
        }

        // Number
        if c.isNumber {
            var j = line.index(after: i)
            while j < line.endIndex && (line[j].isNumber || line[j] == "_" || line[j] == ".") {
                j = line.index(after: j)
            }
            var part = AttributedString(String(line[i..<j]))
            part.foregroundColor = .swNum
            result += part
            i = j
            continue
        }

        // Identifier / keyword / type / function
        if c.isLetter || c == "_" {
            var j = line.index(after: i)
            while j < line.endIndex && (line[j].isLetter || line[j].isNumber || line[j] == "_") {
                j = line.index(after: j)
            }
            let word = String(line[i..<j])
            let nextIsParens = j < line.endIndex && line[j] == "("

            var part = AttributedString(word)
            if swiftKeywords.contains(word) {
                part.foregroundColor = .swKw
            } else if swiftTypes.contains(word) {
                part.foregroundColor = .swType
            } else if word.first?.isUppercase == true {
                part.foregroundColor = .swType
            } else if nextIsParens {
                part.foregroundColor = .swFn
            } else {
                part.foregroundColor = .scInk
            }
            result += part
            i = j
            continue
        }

        // Operators
        let operatorChars = Set("+-*/%=<>!&|^~?:")
        if operatorChars.contains(c) {
            var j = line.index(after: i)
            while j < line.endIndex && operatorChars.contains(line[j]) {
                j = line.index(after: j)
            }
            var part = AttributedString(String(line[i..<j]))
            part.foregroundColor = .swOp
            result += part
            i = j
            continue
        }

        // Punctuation
        let punctChars = Set("{}()[],.;")
        if punctChars.contains(c) {
            var part = AttributedString(String(c))
            part.foregroundColor = .swPunct
            result += part
            i = line.index(after: i)
            continue
        }

        // Whitespace / other
        result += AttributedString(String(c))
        i = line.index(after: i)
    }

    return result
}

// MARK: - Code Editor

struct CodeEditorView: View {
    let code: String
    let annotations: [Annotation]
    let annotationStyle: AnnotationStyle

    enum AnnotationStyle { case gutter, inline, margin }

    private var lines: [String] { code.components(separatedBy: "\n") }
    private var annByLine: [Int: [Annotation]] {
        Dictionary(grouping: annotations, by: \.line)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                    let lineNum = idx + 1
                    let anns = annByLine[lineNum] ?? []
                    let hasError = anns.contains { $0.kind == .error }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 0) {
                            // Gutter
                            ZStack(alignment: .topTrailing) {
                                Text("\(lineNum)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(anns.isEmpty ? Color.scInk4 : Color.scInk2)
                                    .frame(width: 40, alignment: .trailing)
                                    .padding(.trailing, 8)

                                if !anns.isEmpty && annotationStyle == .gutter {
                                    Circle()
                                        .fill(anns[0].kind.accentColor)
                                        .frame(width: 6, height: 6)
                                        .offset(x: -30, y: 6)
                                }
                            }

                            // Code content
                            Text(highlightSwift(line))
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .padding(.trailing, annotationStyle == .margin && !anns.isEmpty ? 220 : 16)
                        }
                        .frame(height: 20)
                        .background(hasError ? Color.scDanger.opacity(0.08) : Color.clear)
                        .overlay(alignment: .leading) {
                            if hasError {
                                Rectangle()
                                    .fill(Color.scDanger)
                                    .frame(width: 2)
                            }
                        }

                        // Inline annotations
                        if annotationStyle == .inline && !anns.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(anns) { ann in
                                    InlineAnnotationView(ann: ann)
                                        .padding(.leading, 48)
                                        .padding(.trailing, 16)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .overlay(alignment: .topTrailing) {
            if annotationStyle == .margin && !annotations.isEmpty {
                MarginAnnotationsView(annotations: annotations)
                    .frame(width: 210)
                    .padding(.top, 8)
                    .padding(.trailing, 4)
            }
        }
    }
}

// MARK: - Annotation subviews

struct InlineAnnotationView: View {
    let ann: Annotation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(ann.kind.label.uppercased())
                .font(.system(size: 9, design: .monospaced).weight(.bold))
                .foregroundStyle(ann.kind.accentColor)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(ann.title)
                    .font(.system(size: 11).weight(.semibold))
                    .foregroundStyle(Color.scInk)
                Text(ann.body)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.scInk2)
            }
        }
        .padding(8)
        .background(ann.kind.accentColor.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(ann.kind.accentColor.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ann.kind.accentColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct MarginAnnotationsView: View {
    let annotations: [Annotation]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(annotations) { ann in
                VStack(alignment: .leading, spacing: 2) {
                    Text("L\(ann.line) · \(ann.kind.label.uppercased())")
                        .font(.system(size: 9, design: .monospaced).weight(.bold))
                        .foregroundStyle(ann.kind.accentColor)
                    Text(ann.body)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.scInk2)
                        .lineLimit(4)
                }
                .padding(8)
                .background(ann.kind.accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ann.kind.accentColor.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .offset(y: CGFloat(ann.line - 1) * 20 - 8)
            }
        }
    }
}
