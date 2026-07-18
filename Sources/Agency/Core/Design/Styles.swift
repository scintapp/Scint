import SwiftUI


struct PickerToggleStyle: ButtonStyle {
    @State private var isHovered = false
    let isSelected: Bool

    private func tint(pressed: Bool) -> Color {
        if pressed { return Color.primary.opacity(0.2) }
        if isSelected { return Color.primary.opacity(0.12) }
        if isHovered { return Color.primary.opacity(0.16) }
        return Color.primary.opacity(0.0)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { isHovered = $0 }
            .background {
                Capsule()
                    .fill(tint(pressed: configuration.isPressed))
                    .frame(maxWidth: 38, maxHeight: 38)
                    .padding([.top, .bottom], 2)
                    .padding([.leading, .trailing], 3)
            }
    }
}

