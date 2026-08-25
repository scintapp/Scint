import SwiftUI


struct BadgeButton: View {
    var label: String
    var image: String
    var tint: Color = Style.Tint.active
    var active: Bool = true

    var primary: Color { active ? Style.Foreground.primary : Style.Foreground.caption }
    var secondary: Color { active ? tint : Style.Foreground.caption }
    var tertiary: Color { active ? Style.Foreground.tertiary : Style.Foreground.caption }

    var body: some View {
        Button { } label: {
            HStack(alignment: .center) {
                Image(systemName: image)
                    .font(.system(size: 10))
                    .foregroundStyle(primary, secondary, tertiary)
                    .symbolRenderingMode(.multicolor)

                Text(label)
                    .font(.system(size: 11.5))
                    .foregroundStyle(primary, secondary, tertiary)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(active ? 1.0 : 0.6)
        }
        .buttonStyle(.borderless)
    }
}

struct BadgeBar: View {
    let model: any Model

    var origin: Reference { model.session.selected.space ?? model.session.workspace }

    var body: some View {
        HStack(alignment: .center) {
            BadgeButton(label: "0", image: "app", tint: Style.Tint.space, active: false) // Spaces
            BadgeButton(label: "2", image: "text.alignleft", tint: Style.Tint.material) // Materials
            BadgeButton(label: "0/3", image: "checkmark.app", tint: Style.Tint.task) // Tasks
            BadgeButton(label: "0", image: "archivebox", tint: Style.Tint.active, active: false) // Artifacts
            BadgeButton(label: "8", image: "switch.2", tint: Style.Tint.command) // Commands
        }
        .frame(maxHeight: 30)
    }
}
