import SwiftUI

extension Color {
    static let scShell    = Color(hex: "0d0d12")
    static let scBg       = Color(hex: "16161c")
    static let scBg2      = Color(hex: "1c1c24")
    static let scBg3      = Color(hex: "22222c")
    static let scBg4      = Color(hex: "2a2a36")
    static let scLine     = Color(hex: "32323f")
    static let scLineSoft = Color(hex: "262630")
    static let scInk      = Color(hex: "e8e8ee")
    static let scInk2     = Color(hex: "b4b4c2")
    static let scInk3     = Color(hex: "75758a")
    static let scInk4     = Color(hex: "4a4a5a")
    // oklch(0.72 0.14 35) → amber
    static let scAccent   = Color(hex: "d4844a")
    // oklch(0.75 0.14 200) → cyan
    static let scAccent2  = Color(hex: "5ac8e0")
    // oklch(0.72 0.16 320) → magenta
    static let scAccent3  = Color(hex: "c050b8")
    // oklch(0.78 0.14 140) → green
    static let scAccent4  = Color(hex: "78c882")
    // oklch(0.78 0.14 80) → yellow
    static let scAccent5  = Color(hex: "c8b84a")
    // oklch(0.68 0.2 25) → danger red
    static let scDanger   = Color(hex: "d0503c")
    // oklch(0.72 0.17 150) → ok green
    static let scOk       = Color(hex: "64c878")

    // Syntax highlight palette
    static let swKw    = Color(hex: "c840a8")
    static let swType  = Color(hex: "5ac8e0")
    static let swFn    = Color(hex: "8cd0e0")
    static let swStr   = Color(hex: "78cc80")
    static let swNum   = Color(hex: "c8b450")
    static let swCm    = Color(hex: "505065")
    static let swOp    = Color(hex: "c0b8d0")
    static let swPunct = Color(hex: "8080a0")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
