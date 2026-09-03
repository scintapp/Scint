import SwiftUI
import LinkPresentation


struct ArtifactCard: View {
    @State private var metadata: LPLinkMetadata?
    let ref: Reference

    private func file(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "file"
        let meta = Artifact.with(ref, { $0.rendered }) ?? ""
        let handle = Artifact.with(ref, { $0.handler }) ?? .file(nil)

        return CardLayout(
            icon: Iconography.icon(for: handle, size: Style.Spacing.xl),
            title: name,
            detail: meta
        )
    }

    @ViewBuilder private func link(_ ref: Reference) -> some View {
        let name = Artifact.with(ref, { $0.name }) ?? "Link"
        let handle = Artifact.with(ref, { $0.handler }) ?? .bookmark(nil)
        if let url = Artifact.with(ref, { $0.handler.url }) ?? nil {
            let panel = url.host(percentEncoded: false) ?? url.absoluteString
            let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = metadata?.url?.host(percentEncoded: false)
            ?? metadata?.originalURL?.host(percentEncoded: false)
            ?? panel

            CardLayout(
                icon: Iconography.icon(for: Artifact.Handler.bookmark(url), size: Style.Spacing.xl),
                title: title?.isEmpty == false ? title! : name,
                detail: detail,
                truncationMode: .middle
            )
            .task(id: url) { await load(url) }
        } else {
            let detail = Artifact.with(ref, { $0.rendered }) ?? ""

            CardLayout(
                icon: Iconography.icon(for: handle, size: Style.Spacing.xl),
                title: name,
                detail: detail,
                truncationMode: .middle
            )
        }
    }

    private func load(_ url: URL) async {
        guard metadata == nil else { return }
        let provider = LPMetadataProvider()
        metadata = try? await provider.startFetchingMetadata(for: url)
    }

    var body: some View {
        switch Artifact.with(ref, { $0.handler }) {
            case .app, .script, .skill, .bookmark: link(ref)
            case .directory, .executable, .file: file(ref)
            default: link(ref)
        }
    }
}

struct TextCard: View {
    let content: String

    var body: some View {
        Text(Attribute.text(content))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskCard: View {
    let content: String
    let completed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.lg) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, 1)

            Text(content)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(completed ? Style.Foreground.faint : Style.Foreground.base)
                .strikethrough(completed, color: Style.Foreground.faint)
                .lineSpacing(Style.Spacing.xs)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, Style.Spacing.md)
        .padding(.vertical, Style.Spacing.sm + 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommandCard: View {
    let ref: Reference

    var body: some View {
        CardLayout(
            icon: Iconography.Icon(
                symbol: Iconography.Custom.dispatch.rawValue,
                tint: Style.Tint.command,
                sizing: Style.Spacing.xl
            ),
            title: Command.with(ref, { $0.name }) ?? "Command",
            detail: BlockSummary.commandDescription(ref)
        )
    }
}

struct MaterialRefCard: View {
    let ref: Reference

    var icon: Iconography.Icon {
        let base = Iconography.icon(for: ref, size: Style.Spacing.xl)
        return Iconography.Icon(symbol: base.symbol, tint: base.tint, sizing: Style.Spacing.xl, tinted: true)
    }
    var name: String { Material.with(ref, { $0.name }) ?? "Material" }
    var description: String { Material.with(ref, { $0.description }) ?? "" }
    var blocks: [Material.Block] { Material.with(ref, { $0.blocks }) ?? [] }
    var facts: [String] { BlockSummary.materialFacts(blocks) }

    var body: some View {
        CardLayout(
            icon: icon,
            title: name,
            detail: description.isEmpty ? BlockSummary.firstPreview(blocks) : description,
            badges: Array(facts.prefix(Style.Limit.cardBadges)),
            detailLineLimit: Style.Limit.doubleLine
        )
    }
}

struct MaterialCard: View {
    @Environment(\.editorFocus) private var focus
    @State private var isHovered = false
    let block: Material.Block
    let isSelected: Bool
    let onFocusGained: () -> Void
    let onEdit: (CGRect) -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool

    @ViewBuilder var content: some View {
        switch block {
            case .artifact(let ref) where ReferencePresentation.of(ref) == .chip:
                HStack {
                    ReferenceChip(ref: ref, label: Artifact.with(ref, { $0.name }) ?? "Artifact")
                    Spacer(minLength: 0)
                }
            case .artifact(let ref): ArtifactCard(ref: ref)
            case .command(let ref): CommandCard(ref: ref)
            case .text(_, let content): TextCard(content: content)
            case .material(let ref): MaterialRefCard(ref: ref)
            case .task(_, let content, let completed): TaskCard(content: content, completed: completed)
        }
    }

    var body: some View {
        content
//            .background {
//                Style.Shape.medium
//                    .fill(
//                        isSelected || isHovered
//                        ? Style.Background.card
//                        : Color.clear
//                    )
//            }
//            .overlay {
//                Style.Shape.medium
//                    .strokeBorder(
//                        isSelected
//                        ? Style.Border.base
//                        : isHovered
//                        ? Style.Border.base
//                        : .clear,
//                        lineWidth: 0.5,
//                        antialiased: true
//                    )
//            }
            .onHover { isHovered = $0 }
            .overlay {
                EntryResponder(
                    id: block.id,
                    focus: focus,
                    onFocusGained: onFocusGained,
                    onEdit: onEdit,
                    onCommand: { onCommand($0, NSRange(location: 0, length: 0), 0) }
                )
            }
    }
}

struct TranscriptCard: View {
    var transcript: Reference
    var model: any Model

    var body: some View {
        let created = Transcript.with(transcript) {
            $0.started ?? transcript.descriptor.created
        } ?? transcript.descriptor.created

        Button { model.select(transcript) } label: {
            HStack(spacing: Style.Spacing.md) {
                Iconography.icon(for: transcript)
                    .frame(
                        width: Style.Spacing.xxl,
                        height: Style.Spacing.xxl
                    )

                VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                    Text(transcript.descriptor.name)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Style.Foreground.muted)
                        .lineLimit(Style.Limit.singleLine)

                    Text(created, style: .time)
                        .font(Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.faint)
                }

                Spacer()
            }
            .padding(.horizontal, Style.Spacing.md)
            .padding(.vertical, Style.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(
//                Style.Shape.medium.fill(
//                    Style.Background.surface
//                )
//            )
            .contentShape(Style.Shape.medium)
        }
        .buttonStyle(.plain)
    }
}

struct CardLayout: View {
    let icon: Iconography.Icon
    let title: String
    let detail: String
    let badges: [String]
    let detailLineLimit: Int
    let truncationMode: Text.TruncationMode
    let monospacedDetail: Bool

    init(
        icon: Iconography.Icon,
        title: String,
        detail: String,
        badges: [String] = [],
        detailLineLimit: Int = Style.Limit.singleLine,
        truncationMode: Text.TruncationMode = .tail,
        monospacedDetail: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.badges = badges
        self.detailLineLimit = detailLineLimit
        self.truncationMode = truncationMode
        self.monospacedDetail = monospacedDetail
    }

    var body: some View {
        let shape = Style.Shape.medium

        HStack(alignment: .center, spacing: Style.Spacing.lg) {
//            Style.Shape.capsule
//                .fill(icon.tint.opacity(Style.Opacity.full))
//                .frame(width: Style.Spacing.sm)

            icon
                .frame(
                    width: Style.Spacing.xxl,
                    height: Style.Spacing.xxl
                )

            VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Style.Foreground.base)
                    .lineLimit(Style.Limit.singleLine)
                    .truncationMode(truncationMode)

                if !detail.isEmpty {
                    Text(detail)
                        .font(monospacedDetail ? Typography.cardDetail(.monospaced) : Typography.cardDetail())
                        .foregroundStyle(Style.Foreground.faint)
                        .lineLimit(detailLineLimit)
                        .truncationMode(truncationMode)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if badges.isEmpty {
                Spacer(minLength: Style.Spacing.md)
            } else {
                HStack(alignment: .center, spacing: Style.Spacing.md) {
                    ForEach(badges, id: \.self) { badge in
                        BadgeButton(label: badge, image: "", tint: icon.tint, active: false)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, Style.Spacing.lg)
        .padding(.vertical, Style.Spacing.lg)
        .contentShape(shape)
        .frame(
            maxWidth: .infinity,
            minHeight: Style.Spacing.cardHeight,
            maxHeight: Style.Spacing.cardHeight,
            alignment: .leading
        )
//        .background(Style.Background.card)
        .clipShape(shape)
//        .overlay {
//            shape.strokeBorder(
//                Color.primary.opacity(Style.Opacity.hairline),
//                lineWidth: 0.5,
//                antialiased: true
//            )
//        }
    }
}
