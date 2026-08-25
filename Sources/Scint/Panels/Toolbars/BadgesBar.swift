import SwiftUI


struct Badge: View {
    var label: String
    var image: String
    var tint: Color = Style.Tint.active
    var active: Bool = true

    var border: Color { active ? tint.opacity(0.4) : Color.primary.opacity(0.2) }
    var background: Color { active ? tint.opacity(0.075) : Color.primary.opacity(0.05) }
    var foreground: Color { active ? Style.Foreground.primary : Style.Foreground.caption }

    var body: some View {
        let badge = Group {
            HStack(spacing: label.isEmpty ? 0 : 5) {
                Image(systemName: image)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: label.isEmpty ? 18 : nil, height: 18)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxHeight: 34)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, label.isEmpty ? 3 : 7)
            .padding(.vertical, label.isEmpty ? 2 : 3)
            .overlay { Style.Shape.badge.strokeBorder(border, lineWidth: 0.75) }
            .opacity(active ? 1.0 : 0.6)
        }

        if active { badge.glassEffect(.regular.tint(background), in: Style.Shape.badge) }
        else { badge.clipShape(Style.Shape.badge) }
    }
}

struct BadgesBar: View {
    let model: any Model

    var origin: Reference { model.session.selected.space ?? model.session.workspace }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Badge(label: "2", image: "text.alignleft", tint: Style.Tint.material)
            Badge(label: "0/3", image: "checkmark.app", tint: Style.Tint.task)
            Badge(label: "0", image: "archivebox", tint: Style.Tint.active, active: false)
            Badge(label: "8", image: "switch.2", tint: Style.Tint.command)
            //                Badge("Executing", image: "gear", tint: Style.Tint.execute)
            //                Badge("Active", image: "app", tint: Style.Tint.active)
        }
    }
}
