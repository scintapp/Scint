import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct Chip: View {
    let ref: Reference
    var label: String? = nil
    var isSelected = false

    @State private var isHovered = false
    @Environment(ScintModel.self) private var scint: ScintModel?

    var body: some View {
        let icon = Iconography.icon(for: ref, size: Style.Dimension.icon)
        let selected = isSelected

        Button {
            CallbackHandler.handle(ref.url, model: scint)
        } label: {
            HStack(spacing: 4) {
                icon
                Text(label ?? ref.descriptor.name)
                    .font(Typography.body)
                    .lineLimit(1)
            }
            .foregroundStyle(icon.tint.bright)
            .padding(.horizontal, 4)
            .frame(height: Typography.Prose.lineHeight)
            .padding(1)
            .background {
                if selected || isHovered {
                    Capsule().fill(icon.tint.bright.opacity(Style.Opacity.surface))
                }
            }
            .overlay {
                Capsule().strokeBorder(
                    icon.tint.bright.opacity(selected ? 1 : Style.Opacity.outline),
                    lineWidth: 1
                )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .referenceMenu(ref)
    }
}

extension View {
    func referenceMenu(_ ref: Reference) -> some View {
        contextMenu {
            Button("Open") {}
            Divider()
            Button("Remove") { }
            Divider()
            Button("Copy") { }
            Button("Duplicate") { }
            Button("Rename") { }
            Button("Move") { }
        }
    }
}
