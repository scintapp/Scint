import SwiftUI


struct Badge: View {
    let label: String
    var symbol: String?
    var tint: Color = Design.Tint.active
    var style: Style = .soft


    enum Style { case soft, neutral }

    init( _ label: String = "", symbol: String? = nil, tint: Color = Design.Tint.active, style: Style = .soft) {
        self.label = label
        self.symbol = symbol
        self.tint = tint
        self.style = style
    }

    private var foreground: Color {
        switch style {
            case .neutral: return Design.Foreground.caption
            case .soft: return Design.Foreground.primary
        }
    }

    private var background: Color {
        switch style {
            case .neutral: return Color.primary.opacity(0.05)
            case .soft: return tint.opacity(0.075)
        }
    }

    private var stroke: Color {
        switch style {
            case .neutral: return Color.primary.opacity(0.2)
            case .soft: return tint.opacity(0.4)
        }
    }

    private var font: Font {
        .system(size: 10, weight: .medium)
    }

    var body: some View {
        HStack(spacing: label.isEmpty ? 0 : 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: label.isEmpty ? 18 : nil, height: 18)
            }

            if !label.isEmpty {
                Text(label)
                    .font(font)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxHeight: 27)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, label.isEmpty ? 3 : 7)
        .padding(.vertical, label.isEmpty ? 2 : 3)
        .background(background)
        .clipShape(Design.Shape.badge)
        .overlay { Design.Shape.badge.strokeBorder(stroke, lineWidth: 0.75) }
    }
}

struct BadgesBar: View {
    let model: any Model
    var origin: Reference { model.session.origin }

    var body: some View {
        if origin.type != Workspace.self {
            HStack(spacing: 6) {
                Badge("0", symbol: "text.alignleft", tint: Design.Tint.scene)
                Badge("0/3", symbol: "checkmark.app", tint: Design.Tint.task)
                Badge("0", symbol: "archivebox", tint: Design.Tint.active, style: .neutral).opacity(0.6)
                Badge("8", symbol: "switch.2", tint: Design.Tint.command)
//                Badge("Executing", symbol: "gear", tint: Design.Tint.execute)
//                Badge("Active", symbol: "app", tint: Design.Tint.active)
            }
            .frame(maxHeight: 30)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}
