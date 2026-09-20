import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


struct Chip: View {
    let ref: Reference
    var label: String? = nil
    var isSelected = false

    @State private var isHovered = false

    var body: some View {
        let icon = Iconography.icon(for: ref, size: Style.Dimension.icon)
        let selected = isSelected

        Button {
            CallbackRouter.open(ref)
        } label: {
            HStack(spacing: Style.Spacing.detail) {
                icon
                Text(label ?? ref.descriptor.name)
                    .font(Typography.body)
                    .lineLimit(1)
            }
            .foregroundStyle(icon.tint.bright)
            .padding(.horizontal, Style.Spacing.detail)
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
            Divider()
            Button("Copy Link") {
                guard let url = Reference.Link.url(for: ref) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
            Button("Copy Markdown Link") {
                guard let markdown = Reference.Link.markdown(for: ref) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(markdown, forType: .string)
            }
        }
    }
}
