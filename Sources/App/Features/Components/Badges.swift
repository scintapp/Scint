import SwiftUI


struct Badge: View {
    var icon: String
    var color: Color
    var glass: Bool
    var label: String
    var count: Int = 0
    var design: Design.Badge { .init(color: color) }
    var padding: (CGFloat, CGFloat) { glass ? (6, 4) : (2, 0) }

    init(icon: String, label: String, count: Int = 0, color: Color, glass: Bool = false) {
        self.icon = icon
        self.label = label
        self.count = count
        self.color = color
        self.glass = glass
    }

    var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(count > 0 ? design.foreground : design.disabledForeground)

            Text("\(label) \(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(count > 0 ? .primary.opacity(0.9) : design.disabledForeground)
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
