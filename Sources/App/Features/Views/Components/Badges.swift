import SwiftUI


struct ComponentBadge {
    let color: Color
    var border: Color { color.opacity(0.17) }
    var background: Color { color.opacity(0.06) }
    var foreground: Color { color.opacity(0.88) }
    var disabledForeground: Color { Color.primary.opacity(0.4) }
    var tableForeground: Color { color.opacity(0.92) }
    var tableGlass: Color { color.opacity(0.14) }
}

struct StatusPill: View {
    let label: String
    var color: Color = Design.Tint.active

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.88))
                .frame(width: EditorComponent.StatusPill.dotSize, height: EditorComponent.StatusPill.dotSize)
            Text(label)
                .font(EditorComponent.StatusPill.font)
        }
        .foregroundStyle(color.opacity(0.88))
        .padding(.horizontal, EditorComponent.StatusPill.horizontalPadding)
        .padding(.vertical, EditorComponent.StatusPill.verticalPadding)
        .background(color.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.17), lineWidth: 1))
    }
}

struct Badge: View {
    var label: String = ""
    var count: Int = 0
    var icon: String?
    var color: Color
    var glass: Bool = false
    var padding: (CGFloat, CGFloat) { glass ? (6, 4) : (2, 0) }

    init(icon: String? = nil, label: String = "", count: Int = 0, color: Color?, glass: Bool = false) {
        self.icon = icon
        self.label = label
        self.count = count
        self.color = color ?? Design.Tint.active
        self.glass = glass
    }

    var badge: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(count > 0 ? Design.Foreground.base : Design.Foreground.disabled)
            }
            Text("\(label) \(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(count > 0 ? Design.Foreground.base : Design.Foreground.disabled)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, padding.0)
        .padding(.vertical, padding.1)
        .contentShape(Capsule())
        .frame(height: 28)
        .frame(maxWidth: 44, maxHeight: 36)
    }

    @ViewBuilder  var body: some View {
        if glass { Group { GlassEffectContainer { badge.glassEffect(.regular, in: Capsule()) } } }
        else { Group { badge } }
    }
}

private struct StatusBadge: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 22)
            .background(.quaternary, in: Capsule())
    }
}

private struct StateBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

private struct InfoBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quinary, in: Capsule())
    }
}

struct CardBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(EditorComponent.Badge.font)
            .foregroundStyle(EditorComponent.Badge.foreground)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, EditorComponent.Badge.horizontalPadding)
            .padding(.vertical, EditorComponent.Badge.verticalPadding)
            .background(EditorComponent.Badge.background)
            .clipShape(RoundedRectangle(cornerRadius: EditorComponent.Badge.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EditorComponent.Badge.cornerRadius, style: .continuous)
                    .strokeBorder(EditorComponent.Badge.stroke, lineWidth: 0.75)
            }
    }
}
