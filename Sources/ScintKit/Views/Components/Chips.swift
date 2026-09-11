import AppKit
import SwiftUI


struct Chip: View {
    let ref: Reference
    var label: String? = nil
    var isSelected = false

    @State private var isHovered = false

    var body: some View {
        let icon = Iconography.icon(for: ref, size: Typography.Scale.inline)
        let selected = isSelected || ReferenceSelection.shared.selected == ref

        Button {
            ReferenceSelection.shared.selected = ref
            CallbackRouter.open(ref)
        } label: {
            HStack(spacing: Style.Spacing.sm) {
                icon
                Text(label ?? ref.descriptor.name)
                    .font(Typography.chip)
                    .lineLimit(Style.Limit.singleLine)
            }
            .foregroundStyle(icon.tint)
            .padding(.horizontal, Style.Spacing.sm)
            .frame(height: Typography.Prose.appKitLineHeight)
            .padding(Style.Spacing.xxs)
            .background {
                if selected || isHovered {
                    Style.Shape.capsule.fill(icon.tint.opacity(Style.Opacity.washed))
                }
            }
            .overlay {
                Style.Shape.capsule.strokeBorder(
                    icon.tint.opacity(selected ? Style.Opacity.strong : Style.Opacity.faint),
                    lineWidth: Style.Dimension.border
                )
            }
            .contentShape(Style.Shape.capsule)
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
