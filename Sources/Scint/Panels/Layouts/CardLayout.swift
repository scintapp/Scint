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

    var attributed: AttributedString {
        var attributed = AttributedString(content)
        attributed.font = Typography.prose
        attributed.foregroundColor = Style.Foreground.base

        Markdown.parse(content).forEach { inline in
            guard let range = attributedRange(inline.range, source: content, attributed: attributed) else {
                return
            }

            switch inline.kind {
                case .heading(let level):
                    attributed[range].font = Typography.heading(level)
                    let lineRange = (content as NSString).lineRange(for: inline.range)
                    if let paragraphRange = attributedRange(lineRange, source: content, attributed: attributed) {
                        attributed[paragraphRange].paragraphStyle = Typography.Prose.headingParagraphStyle(level)
                    }

                case .quote:
                    attributed[range].font = Typography.quote
                    attributed[range].foregroundColor = Style.Foreground.base.opacity(Style.Opacity.muted)

                case .quoteMarker:
                    attributed[range].foregroundColor = Style.Foreground.base.opacity(Style.Opacity.faint)

                case .codeFence:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = Style.Foreground.base.opacity(Style.Opacity.washed)

                case .strong:
                    attributed[range].font = Typography.prose.weight(.semibold)

                case .emphasis:
                    attributed[range].font = Typography.prose.italic()

                case .inlineCode:
                    attributed[range].font = Typography.proseCode
                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.full)

                case .strikethrough:
                    attributed[range].foregroundColor = Style.Foreground.base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .syntax:
                    attributed[range].font = Typography.Prose.syntaxHidden
                    attributed[range].foregroundColor = .clear

                case .codeBlock:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = Style.Foreground.base.opacity(
                        Style.Opacity.disabled
                    )
            }
        }

        return attributed
    }

    var body: some View {
        Text(attributed)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributedRange(_ range: NSRange, source: String, attributed: AttributedString) -> Range<AttributedString.Index>? {
        guard let sourceRange = Range(range, in: source) else { return nil }

        let lowerOffset = source.distance(from: source.startIndex, to: sourceRange.lowerBound)
        let upperOffset = source.distance(from: source.startIndex, to: sourceRange.upperBound)
        let characters = attributed.characters
        let lowerBound = characters.index(characters.startIndex, offsetBy: lowerOffset)
        let upperBound = characters.index(characters.startIndex, offsetBy: upperOffset)
        return lowerBound..<upperBound
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
        let name = Command.with(ref, { $0.name }) ?? "tool"

        return CardLayout(
            icon: Iconography.Icon(
                symbol: Iconography.Custom.dispatch.rawValue,
                tint: Style.Tint.command,
                sizing: Style.Spacing.xl
            ),
            title: name,
            detail: BlockSummary.commandDescription(ref)
        )
    }
}

struct MaterialCard: View {
    @Environment(\.editorFocus) private var focus
    @State private var isHovered = false
    let block: Material.Block
    let selection: NSRange?
    let isEditing: Bool
    let isSelected: Bool
    let onTextChange: (String, NSRange) -> Void
    let onSelectionChange: (NSRange) -> Void
    let onCaretRectChange: (CGRect) -> Void
    let onViewportRectChange: (CGRect) -> Void
    let onFocusGained: () -> Void
    let onEdit: () -> Void
    let onCommand: (Selector, NSRange, Int) -> Bool

    func material(_ ref: Reference) -> some View {
        let name = Material.with(ref, { $0.name }) ?? "Material"
        let description = Material.with(ref, { $0.description }) ?? ""
        let blocks = Material.with(ref, { $0.blocks }) ?? []
        let facts = BlockSummary.materialFacts(blocks)

        return CardLayout(
            icon: Iconography.Icon(
                symbol: "text.alignleft",
                tint: Style.Tint.material,
                sizing: Style.Spacing.xl
            ),
            title: name,
            detail: description.isEmpty ? BlockSummary.firstPreview(blocks) : description,
            badges: Array(facts.prefix(Style.Limit.cardBadges)),
            detailLineLimit: Style.Limit.doubleLine
        )
    }

    @ViewBuilder var content: some View {
        switch block {
            case .artifact(let ref): ArtifactCard(ref: ref)
            case .command(let ref): CommandCard(ref: ref)
            case .text(_, let content): TextCard(content: content)
            case .material(let ref): material(ref)
            case .task(_, let content, let completed): TaskCard(content: content, completed: completed)
        }
    }

    var body: some View {
        switch block {
            case .text(_, let text):
                EditorInput(
                    id: block.id,
                    text: text,
                    selection: selection,
                    isEditing: isEditing,
                    onTextChange: onTextChange,
                    onSelectionChange: onSelectionChange,
                    onCaretRectChange: onCaretRectChange,
                    onViewportRectChange: onViewportRectChange,
                    onFocusGained: onFocusGained,
                    onCommand: onCommand
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            default:
                content
                    .background {
                        Style.Shape.medium
                            .fill(
                                isSelected
                                ? Color.primary.opacity(Style.Opacity.hairline)
                                : isHovered
                                ? Color.primary.opacity(Style.Opacity.hairline)
                                : Color.clear
                            )
                    }
                    .overlay {
                        Style.Shape.medium
                            .strokeBorder(
                                isSelected
                                ? Style.Tint.space.opacity(Style.Opacity.washed)
                                : isHovered
                                ? Color.primary.opacity(Style.Opacity.hairline)
                                : .clear,
                                lineWidth: 1
                            )
                    }
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
            .background(
                Style.Shape.medium.fill(
                    Style.Background.panel.opacity(Style.Opacity.washed)
                )
            )
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
            Style.Shape.capsule
                .fill(icon.tint.opacity(Style.Opacity.full))
                .frame(width: Style.Spacing.sm)

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
        .background(Style.Background.panel.opacity(Style.Opacity.washed))
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.primary.opacity(Style.Opacity.hairline),
                lineWidth: 1
            )
        }
    }
}
