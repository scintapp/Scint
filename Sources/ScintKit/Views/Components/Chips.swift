import AppKit
import SwiftUI


struct ReferenceChip: View {
    let ref: Reference
    var label: String? = nil
    var isSelected = false

    @State private var isHovered = false

    var body: some View {
        let icon = Iconography.icon(for: ref, size: Typography.Scale.inline)
        let selected = isSelected || ReferenceSelection.shared.selected == ref

        Button {
            ReferenceSelection.shared.selected = ref
            ReferenceRouter.open(ref)
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

#if DEBUG
#Preview("Chips") {
    let previewData = FileManager.default.temporaryDirectory
        .appending(path: "ScintCardPreviews")
        .appending(path: String(ProcessInfo.processInfo.processIdentifier))
    precondition(setenv("XDG_DATA_HOME", previewData.path, 1) == 0)

    let workspace = Workspace.new("Research Desk")
    let material = Material.new(workspace, name: "Research Brief Template")
    let file = Artifact.register("Design notes.md", previewData.appending(path: "Design notes.md"))
    let executable = Artifact.register("curl", URL(filePath: "/usr/bin/curl"))
    let command = Command.register("Fetch Web Page", exec: executable)

    return VStack(alignment: .leading, spacing: Style.Spacing.lg) {
        ReferenceChip(ref: material)
        ReferenceChip(ref: command)
        ReferenceChip(ref: file)
        ReferenceChip(ref: workspace)
        ReferenceChip(ref: material, label: "Selected reference", isSelected: true)
    }
    .padding(Style.Spacing.xxl)
    .frame(width: Style.Spacing.contentMaxWidth, alignment: .leading)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}
#endif
