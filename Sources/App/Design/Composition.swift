import AgencyRuntime
import SwiftUI


// MARK: - These are more or less placeholders, but will be used eventually

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
