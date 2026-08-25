import SwiftUI

enum Typography {
    static let message = Font.system(size: 13.5)
    static let body = Font.system(size: 12.5)
    static let label = Font.system(size: 10, weight: .medium)
    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)

    enum Prose {
        static let body: CGFloat = 14.6
        static let h1: CGFloat = 24
        static let h2: CGFloat = 21
        static let h3: CGFloat = 18
        static let code: CGFloat = 13.2
        static let caption: CGFloat = 12

        static var text: Font { .system(size: body) }
        static var heading1: Font { .system(size: h1, weight: .heavy) }
        static var heading2: Font { .system(size: h2, weight: .bold) }
        static var heading3: Font { .system(size: h3, weight: .semibold) }
        static var monospaced: Font { .system(size: code, design: .monospaced) }

        static func heading(_ level: Int) -> Font {
            switch level {
                case 1: return heading1
                case 2: return heading2
                default: return heading3
            }
        }
    }

    enum Card {
        static let title = Font.system(size: 13.5, weight: .semibold)
        static let detail = Font.system(size: 12.5, weight: .regular)
        static func detail(_ design: Font.Design) -> Font {
            .system(size: 12, weight: .medium, design: design)
        }
    }
}
