import LinkPresentation
import SwiftUI
import ScintRuntime
import ScintComponents


enum CardStyle { case group, list, node }

struct Card: View {
    let ref: Reference
    let style: CardStyle
    var onSelect: (() -> Void)? = nil
    var isSelected: Bool = false

    @State var isHovered: Bool = false
    @State var linkMetadata: (url: URL, value: LPLinkMetadata)?
    @Environment(ScintModel.self) private var scint: ScintModel?

    var url: URL? { Self.link(for: ref) }
    var metadata: LPLinkMetadata? { linkMetadata.flatMap { $0.url == url ? $0.value : nil } }
    var selected: Bool { isSelected }
    var icon: Iconography.Icon { Iconography.icon(for: ref, size: style == .list ? 18 : 16) }

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

        guard let blocks = Document.with(ref, { $0.blocks }),
              case .text(_, let first)? = blocks.first,
              let heading = first.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).first,
              heading.hasPrefix("# ")
        else { return result }

        let title = heading.dropFirst(2).trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { result.name = title }

        if case .text(_, let text)? = blocks.dropFirst().first {
            let description = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .prefix(2)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty { result.description = description }
        }

        return result
    }

    static func badges(for ref: Reference) -> [String] {
        switch ref.type {
            case is ScintRuntime.Document.Type:
                return Document.with(ref) { document in
                    var counts = ComponentCount()
                    counts.include(document.blocks)

                    return counts.totalTasks > 0 ? ["\(counts.completedTasks)/\(counts.totalTasks) tasks"] : []
                } ?? []

            case is Space.Type:
                return Space.with(ref) { space in
                    let documents = space.documents
                    var counts = ComponentCount()
                    for document in documents {
                        ScintRuntime.Document.with(document) { counts.include($0.blocks, countDocuments: false) }
                    }

                    return [
                        "\(documents.count) document\(documents.count == 1 ? "" : "s")",
                        "\(counts.completedTasks)/\(counts.totalTasks) tasks"
                    ]
                } ?? []

            case is Harness.Type:
                return Harness.with(ref) { [$0.intent.rawValue] } ?? []

            case is Transcript.Type:
                return Transcript.with(ref) { transcript in
                    for case .event(let signal, _) in transcript.entries.reversed() {
                        return switch signal {
                            case .compose: ["composed"]
                            case .start, .update: ["active"]
                            case .complete: ["completed"]
                            case .stop: ["stopped"]
                            case .fail: ["failed"]
                        }
                    }
                    return []
                } ?? []

            default: return []
        }
    }

    var content: some View {
        let text = Self.text(for: ref, metadata: metadata)
        let badges = Array(Self.badges(for: ref).prefix(Metrics.cardBadges))

        return VStack(alignment: .leading) {
            HStack(alignment: .center, spacing: 8) {
                icon
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.leading, 4)
                    .padding(.trailing, 6)

                VStack(alignment: .leading) {
                    Text(text.name)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .font(Typography.body.weight(.medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)

                    if !text.description.isEmpty {
                        Text(text.description)
                            .font(Typography.detail)
                            .foregroundStyle(Style.Foreground.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }

                Spacer()

                if !badges.isEmpty {
                    HStack(spacing: 4) {
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
        let shape = Style.Shape.card

        Button {
            if let onSelect { onSelect() }
            else {
                CallbackHandler.handle(ref.url, model: scint)
            }
        } label: {
            switch style {
                case .group:
                    VStack {
                        content
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, maxHeight: 80, alignment: .leading)
                    }
                    .background { selected ? shape.fill(icon.tint.opacity(0.03)) : shape.fill(Style.Background.surface) }
                    .overlay {
                        shape.strokeBorder(
                            selected || isHovered
                            ? icon.tint.opacity(selected ? 1 : Style.Opacity.inactive)
                            : Style.Border.hairline,
                            lineWidth: selected ? 1 : 0.5
                        )
                    }
                    .contentShape(shape)
                    .offset(y: isHovered ? -1 : 0)
                    .onHover { hovered in
                        withAnimation(Style.Motion.disclosure) {
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
                    HStack(spacing: 8) {
                        icon
                        Text(Self.text(for: ref, metadata: metadata).name)
                            .font(Typography.body)
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight, alignment: .leading)
                    .background {
                        if selected || isHovered {
                            Style.Shape.control.fill(
                                selected
                                ? icon.tint.opacity(Style.Opacity.surface)
                                : Style.Foreground.primary.opacity(Style.Opacity.surface)
                            )
                        }
                    }
                    .contentShape(Style.Shape.control)
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
