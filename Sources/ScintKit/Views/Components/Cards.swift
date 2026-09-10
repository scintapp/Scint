import SwiftUI


struct ReferenceCard: View {
    let ref: Reference
    var isSelected = false
    var onSelect: (() -> Void)? = nil

    @State private var isHovered = false

    static func text(for ref: Reference) -> (name: String, description: String) {
        let descriptor = ref.descriptor
        var result = (name: descriptor.name, description: descriptor.description)

        guard let blocks = Material.with(ref, { $0.blocks }),
              case .text(_, let first)? = blocks.first,
              let heading = first.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).first,
              heading.hasPrefix("# ")
        else { return result }

        let title = heading.dropFirst(2).trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { result.name = title }

        if case .text(_, let text)? = blocks.dropFirst().first {
            let description = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .prefix(Style.Limit.doubleLine)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty { result.description = description }
        }

        return result
    }

    static func badges(for ref: Reference) -> [String] {
        switch ref.type {
            case is Material.Type:
                return Material.with(ref) { material in
                    var counts = EntryCounts()
                    counts.include(material.blocks)

                    return counts.totalTasks > 0 ? ["\(counts.completedTasks)/\(counts.totalTasks) tasks"] : []
                } ?? []

            case is Space.Type:
                return Space.with(ref) { space in
                    let materials = space.materials
                    var counts = EntryCounts()
                    for material in materials {
                        Material.with(material) { counts.include($0.blocks, countMaterials: false) }
                    }

                    return [
                        "\(materials.count) material\(materials.count == 1 ? "" : "s")",
                        "\(counts.completedTasks)/\(counts.totalTasks) tasks"
                    ]
                } ?? []

            case is Harness.Type:
                return Harness.with(ref) { [$0.intent.rawValue] } ?? []

            case is Transcript.Type:
                return Transcript.with(ref) { transcript in
                    for case .event(let signal, _) in transcript.entries.reversed() {
                        return switch signal {
                            case .composed: ["composed"]
                            case .started, .updated: ["active"]
                            case .completed: ["completed"]
                            case .stopped: ["stopped"]
                            case .failed: ["failed"]
                        }
                    }
                    return []
                } ?? []

            default: return []
        }
    }

    var body: some View {
        let text = Self.text(for: ref)
        let icon = Iconography.icon(for: ref)
        let badges = Array(Self.badges(for: ref).prefix(Style.Limit.cardBadges))
        let selected = isSelected || ReferenceSelection.shared.selected == ref
        let shape = Style.Shape.medium

        Button {
            if let onSelect {
                onSelect()
            } else {
                ReferenceSelection.shared.selected = ref
                ReferenceRouter.open(ref)
            }
        } label: {
            VStack(alignment: .leading, spacing: Style.Spacing.md) {
                HStack(alignment: .top, spacing: Style.Spacing.lg) {
                    HStack(spacing: Style.Spacing.md) {
                        icon
                        Text(text.name)
                            .font(Typography.cardTitle)
                            .foregroundStyle(Style.Foreground.base)
                            .lineLimit(Style.Limit.singleLine)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    if !badges.isEmpty {
                        HStack(spacing: Style.Spacing.sm) {
                            ForEach(Array(badges.enumerated()), id: \.offset) { _, label in
                                Badge(label: label, tint: icon.tint, outlined: true)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }

                if !text.description.isEmpty {
                    Text(text.description)
                        .font(Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.muted)
                        .lineLimit(Style.Limit.doubleLine)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Style.Spacing.xl)
            .padding(.vertical, Style.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: Style.Spacing.cardHeight, alignment: .leading)
            .background(shape.fill(Style.Background.card))
            .overlay {
                shape.strokeBorder(
                    selected || isHovered
                        ? icon.tint.opacity(selected ? Style.Opacity.strong : Style.Opacity.muted)
                        : Color.primary.opacity(Style.Opacity.hairline),
                    lineWidth: selected || isHovered ? Style.Dimension.border : Style.Dimension.hairline
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .referenceMenu(ref)
    }
}


#if DEBUG
#Preview("Cards") {
    let previewData = FileManager.default.temporaryDirectory
        .appending(path: "ScintCardPreviews")
        .appending(path: String(ProcessInfo.processInfo.processIdentifier))
    precondition(setenv("XDG_DATA_HOME", previewData.path, 1) == 0)

    let workspace = Workspace.new("Research Desk")
    Workspace.update(workspace) { $0.description = "Shared research, materials, and tools." }
    let space = Space.new(workspace, name: "Client research")
    Space.update(space) { $0.description = "Prepare the next discovery call." }
    let file = Artifact.register("Design notes.md", previewData.appending(path: "Design notes.md"))
    Artifact.update(file) { $0.description = "Notes and reference material for the interview." }
    let link = Artifact.register("SwiftUI documentation", URL(string: "https://developer.apple.com/documentation/swiftui")!)
    Artifact.update(link) { $0.description = "Apple's documentation for SwiftUI." }
    let executable = Artifact.register("curl", URL(filePath: "/usr/bin/curl"))
    let command = Command.register("Fetch Web Page", exec: executable, params: [
        .fixed(.string("-L")),
        .fixed(.string("--max-time 20")),
        .argument(name: "URL", type: .string(""), required: true)
    ])
    Command.update(command) { $0.description = "Fetch the contents of a web page with curl." }
    let harness = Harness.register("Research Harness", command: command, intent: .observe)
    Harness.update(harness) { $0.description = "Observe changes while collecting research." }

    let material = Material.new(space, name: "Descriptor fallback title")
    Material.update(material) {
        $0.description = "Descriptor fallback description."
        $0.update(.text(UUID(), "# Research Brief Template"), at: 0)
        $0.insert(.text(UUID(), "Turn a topic into a research brief with a working question, audience context, and source plan.\nCapture the intended use of the finished brief."), at: nil)
        $0.insert(.task(UUID(), "Review the brief", false), at: nil)
        $0.insert(.task(UUID(), "Collect design references", true), at: nil)
        $0.insert(.artifact(file), at: nil)
    }
    let fallback = Material.new(space, name: "Material without a heading")
    Material.update(fallback) {
        $0.description = "This card uses its descriptor because the heading and following text are absent."
        $0.delete(at: 0)
    }
    let transcript = Transcript.new(workspace)
    Transcript.update(transcript) {
        $0.name = "Observe Transcript"
        $0.description = "Watch the Research Desk for changes."
    }
    let refs = [material, fallback, command, harness, transcript, file, link, space, workspace]

    return ScrollView {
        VStack(alignment: .leading, spacing: Style.Spacing.xl) {
            ForEach(refs) { ref in
                ReferenceCard(ref: ref)
            }
        }
        .padding(Style.Spacing.xxl)
    }
    .frame(width: Style.Spacing.contentMaxWidth, height: Style.Dimension.taskPanel.height)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}
#endif
