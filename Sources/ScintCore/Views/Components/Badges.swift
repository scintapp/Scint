import SwiftUI


struct Badge: View {
    enum Style {
        case soft
        case neutral
    }

    let label: String
    var symbol: String?
    var tint: Color = Design.Tint.active
    var style: Style = .soft
    var monospaced = false

    init(
        _ label: String = "",
        symbol: String? = nil,
        tint: Color = Design.Tint.active,
        style: Style = .soft,
        monospaced: Bool = false
    ) {
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.style = style
        self.monospaced = monospaced
    }

    private var foreground: Color {
        switch style {
            case .neutral: return Design.Foreground.caption
            case .soft: return tint.opacity(0.9)
        }
    }

    private var background: Color {
        switch style {
            case .neutral: return Color.primary.opacity(0.075)
            case .soft: return tint.opacity(0.075)
        }
    }

    private var stroke: Color {
        switch style {
            case .neutral: return Color.primary.opacity(0.09)
            case .soft: return tint.opacity(0.18)
        }
    }

    private var font: Font {
        .system(size: 10.5, weight: .medium, design: monospaced ? .monospaced : .default)
    }

    var body: some View {
        HStack(spacing: label.isEmpty ? 0 : 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                    .frame(width: label.isEmpty ? 18 : nil, height: 18)
            }

            if !label.isEmpty {
                Text(label)
                    .font(font)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, label.isEmpty ? 3 : 7)
        .padding(.vertical, label.isEmpty ? 2 : 3)
        .frame(minHeight: 22)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(stroke, lineWidth: 0.75)
        }
    }
}
