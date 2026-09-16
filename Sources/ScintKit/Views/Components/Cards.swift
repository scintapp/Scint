import SwiftUI
import LinkPresentation


enum CardStyle { case group, list, node }

struct Card: View {
    let ref: Reference
    let style: CardStyle
    var onSelect: (() -> Void)? = nil

    @State var isSelected: Bool = false
    @State var isHovered: Bool = false
    @State var linkMetadata: (url: URL, value: LPLinkMetadata)?

    var url: URL? { Self.link(for: ref) }
    var metadata: LPLinkMetadata? { linkMetadata.flatMap { $0.url == url ? $0.value : nil } }
    var selected: Bool { isSelected }
    var icon: Iconography.Icon { Iconography.icon(for: ref, size: style == .list ? 18 : 14) }

    static func link(for ref: Reference) -> URL? {
        Artifact.with(ref) { artifact in
            guard case .bookmark(let url) = artifact.handler else { return nil }
            return url
        } ?? nil
    }

    static func text(for ref: Reference, metadata: LPLinkMetadata? = nil) -> (name: String, description: String) {
        let descriptor = ref.descriptor
        var result = (name: descriptor.name, description: descriptor.description)

        if let url = link(for: ref) {
            if let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                result.name = title
            }
            result.description = metadata?.url?.host(percentEncoded: false)
            ?? metadata?.originalURL?.host(percentEncoded: false)
            ?? url.host(percentEncoded: false)
            ?? url.absoluteString
            return result
        }

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
                    var counts = ComponentCount()
                    counts.include(material.blocks)

                    return counts.totalTasks > 0 ? ["\(counts.completedTasks)/\(counts.totalTasks) tasks"] : []
                } ?? []

            case is Space.Type:
                return Space.with(ref) { space in
                    let materials = space.materials
                    var counts = ComponentCount()
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

    var content: some View {
        let text = Self.text(for: ref, metadata: metadata)
        let badges = Array(Self.badges(for: ref).prefix(Style.Limit.cardBadges))

        return VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                icon
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack(alignment: .leading) {
                    Text(text.name)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(Style.Limit.singleLine)

                    if !text.description.isEmpty {
                        Text(text.description)
                            .font(Typography.cardDetail())
                            .foregroundStyle(Style.Foreground.muted)
                            .lineLimit(Style.Limit.doubleLine)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }

                Spacer()

                if !badges.isEmpty {
                    HStack(spacing: Style.Spacing.sm) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { _, label in
                            Badge(label: label, tint: icon.tint, outlined: true)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 30, alignment: .center)
            .layoutPriority(1)
        }
    }

    var body: some View {
        let shape = Style.Shape.large

        Button {
            if let onSelect { onSelect() }
            else {
                CallbackRouter.open(ref)
            }
        } label: {
            switch style {
                case .group:
                    VStack {
                        content
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, maxHeight: 80, alignment: .leading)
                    }
                    .background { selected ? shape.fill(icon.tint.opacity(0.03)) : shape.fill(Style.Background.card) }
                    .overlay {
                        shape.strokeBorder(
                            selected || isHovered
                            ? icon.tint.opacity(selected ? Style.Opacity.strong : Style.Opacity.muted)
                            : Style.Border.card,
                            lineWidth: selected ? 1 : 0.5
                        )
                    }
                    .contentShape(shape)
                    .offset(y: isHovered ? -1 : 0)
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: Style.Duration.interaction)) {
                            isHovered = hovered
                        }
                    }

                case .list:
                    VStack {
                        content
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 8)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, maxHeight: 80, alignment: .leading)
                            .contentShape(shape)
                        Divider()
                            .padding(.leading, 24)
                    }

                case .node:
                    HStack(spacing: Style.Spacing.md) {
                        icon
                        Text(Self.text(for: ref, metadata: metadata).name)
                            .font(Typography.row)
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(Style.Limit.singleLine)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Style.Spacing.sm)
                    .frame(maxWidth: .infinity, minHeight: Style.Spacing.rowHeight, alignment: .leading)
                    .background {
                        if selected || isHovered {
                            Style.Shape.tiny.fill(
                                selected
                                ? icon.tint.opacity(Style.Opacity.washed)
                                : Style.Foreground.primary.opacity(Style.Opacity.hairline)
                            )
                        }
                    }
                    .contentShape(Style.Shape.tiny)
                    .onHover { isHovered = $0 }
            }
        }
        .buttonStyle(.plain)
        .referenceMenu(ref)
        .task(id: url) {
            guard linkMetadata?.url != url else { return }
            linkMetadata = nil
            guard let url else { return }
            let provider = LPMetadataProvider()
            guard let metadata = try? await provider.startFetchingMetadata(for: url), !Task.isCancelled else { return }
            linkMetadata = (url, metadata)
        }
    }
}
