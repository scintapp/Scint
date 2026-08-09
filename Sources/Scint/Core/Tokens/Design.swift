import SwiftUI


enum Spacing {
    static let blockRadius: CGFloat = 12
    static let blockPaddingV: CGFloat = 10
    static let blockPaddingH: CGFloat = 10
    static let blockSpacing: CGFloat = 12
    static let messageExtraSpacing: CGFloat = 6
    static let quoteBarWidth: CGFloat = 0.5
    static let quoteInset: CGFloat = 22
    static let lineSpacingMessage: CGFloat = 5
    static let lineSpacingBody: CGFloat = 5
    static let lineSpacingMono: CGFloat = 4
}

enum Typography {
    static let message = Font.system(size: 13.5)
    static let body = Font.system(size: 12.5)
    static let label = Font.system(size: 10, weight: .medium)
    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
}

enum Design {
    enum Shape {
        static var tab: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .continuous) }
        static var badge: RoundedRectangle { Design.Shape.menu }
        static var block: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }
        static var bubble: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
        static var node: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }
        static var card: RoundedRectangle { RoundedRectangle(cornerRadius: 23, style: .continuous) }
        static var menu: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
        static var input: RoundedRectangle { RoundedRectangle(cornerRadius: 28, style: .circular) }
        static var panel: RoundedRectangle { RoundedRectangle(cornerRadius: 30, style: .continuous) }
    }

    enum Border {
        static var block: Color { Color(red: 0.149, green: 0.149, blue: 0.153) }
        static var card: Color { Color(red: 0.149, green: 0.149, blue: 0.153) }
        static var hairline: Color { block.opacity(0.12) }
        static var cardBorder: Color { Color.white.opacity(0.09) }
        static var controlBorder: Color {Color.white.opacity(0.11) }
    }

    enum Background {
        static var base: Color { Color(red: 0.103, green: 0.104, blue: 0.107) }
        static var block: Color { Color(red: 0.123, green: 0.126, blue: 0.135) }
        static var card: Color { Color(red: 0.095, green: 0.095, blue: 0.095) }
        static var console: Color { Color(red: 0.095, green: 0.095, blue: 0.095) }
        static var detail: Color { Color(red: 0.098, green: 0.098, blue: 0.095) }
        static var editor: Color { Color(red: 0.095, green: 0.095, blue: 0.095) }
        static var menu: Color { Color(red: 0.162, green: 0.165, blue: 0.169, opacity: 0.36) }
        static var panel: Color { Color(red: 0.162, green: 0.165, blue: 0.169, opacity: 0.36) }
        static var palette: Color { Color(red: 0.098, green: 0.098, blue: 0.098) }
        static var surface: Color { Color(red: 0.123, green: 0.124, blue: 0.128) }
        static var raised: Color { .white.opacity(0.05) }
    }

    enum Foreground {
        static var accent: Color { .accent }
        static var text: Color { Color(red: 1.502, green: 1.508, blue: 1.518) }
        static var primary: Color { .primary.opacity(0.9) }
        static var secondary: Color { .primary.opacity(0.76) }
        static var tertiary: Color { .secondary.opacity(0.8) }
        static var quaternary: Color { .secondary.opacity(0.66) }
        static var caption: Color { .secondary.opacity(0.9) }
        static var disabled: Color { .secondary.opacity(0.6) }
    }

    enum Tint {

        static var compose: Color { Color(red: 1.131, green: 0.880, blue: 1.499) }
        static var dispatch: Color { Color(red: 1.258, green: 1.087, blue: 1.547) }
        static var execute: Color { Color(red: 1.338, green: 0.817, blue: 0.947) }
        static var observe: Color { Color(red: 0.810, green: 1.191, blue: 1.443) }
        static var traverse: Color { Color(red: 0.748, green: 1.004, blue: 1.407) }

        static var inactive: Color { Color(red: 0.620, green: 0.590, blue: 0.640) }
        static var active: Color { Color(red: 0.888, green: 0.954, blue: 1.127) }
        static var running: Color { Color(red: 0.723, green: 0.781, blue: 0.809) }
        static var blocked: Color { Color(red: 0.801, green: 0.630, blue: 0.506) }
        static var failed: Color { Color(red: 0.796, green: 0.555, blue: 0.662) }

        static var info: Color { Color(red: 0.980, green: 1.040, blue: 1.305) }
        static var request: Color { Color(red: 1.090, green: 0.920, blue: 1.120) }
        static var warning: Color { Color(red: 0.893, green: 0.718, blue: 0.660) }
        static var error: Color { Color(red: 0.776, green: 0.455, blue: 0.562) }

        static var artifact: Color { Color(red: 0.858, green: 1.007, blue: 1.347) }
        static var command: Color { Color(red: 1.158, green: 1.009, blue: 1.447) }
        static var harness: Color { Color(red: 0.743, green: 0.901, blue: 0.920) }
        static var scene: Color { Color(red: 1.463, green: 1.08887, blue: 0.980) }
        static var space: Color { Color(red: 1.276, green: 1.36706, blue: 1.472) }
        static var task: Color { Color(red: 1.384, green: 0.817, blue: 0.947) }
        static var workspace: Color { Color(red: 1.277, green: 1.367, blue: 1.472) }
    }
}
