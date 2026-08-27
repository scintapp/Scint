import SwiftUI


struct TranscriptEntry: View {
    var transcript: Reference
    var entry: Transcript.Entry
    var model: any Model

    private var input: String? {
        switch entry {
            case .material(let ref, _) where ref.descriptor.tags.contains("input"):
                Material.with(ref, { $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines) })

            case .value("input", let value, _):
                value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

            default:
                nil
        }
    }

    var body: some View {
        Group {
            if let input, !input.isEmpty {
                HStack {
                    Spacer()

                    Text(input)
                        .foregroundStyle(Style.Foreground.subtle)
                        .padding(.horizontal, Style.Spacing.lg)
                        .padding(.vertical, Style.Spacing.lg)
                        .background(Style.Shape.medium.fill(Style.Background.overlay))
                        .overlay(
                            Style.Shape.medium
                                .strokeBorder(Style.Border.group, lineWidth: 0.5)
                        )
                }
            } else {
                switch entry {
                    case .event(_, .updated(let value), _), .event(_, .failed(let value), _):
                        switch TranscriptContent(value) {
                            case .message(let text):
                                Text(attributed(text))

                            case .reasoning(let text):
                                Text(attributed(text, reasoning: true))

                            case .tool(let name, let verb):
                                HStack(spacing: Style.Spacing.md) {
                                    Iconography.model(.material(.command))
                                    Text("\(verb) \(name)")
                                    Spacer()
                                }

                            case nil:
                                EmptyView()
                        }

                    case .transcript(let ref, _):
                        TranscriptCard(transcript: ref, model: model)

                    case .value(let key, let value, _) where key != "context" && key != "input":
                        Text(value.rendered.joined(separator: "\n"))

                    case .event, .material, .value:
                        EmptyView()
                }
            }
        }
        .font(Typography.prose)
        .foregroundStyle(Style.Foreground.base)
        .lineSpacing(Style.Spacing.sm)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .transcript = entry { return }
            model.select(transcript)
        }
    }

    private func attributed(_ text: String, reasoning: Bool = false) -> AttributedString {
        let baseColor = reasoning ? Style.Foreground.faint : Style.Foreground.base
        var attributed = AttributedString(text)
        attributed.font = reasoning ? Typography.prose.italic() : Typography.prose
        attributed.foregroundColor = baseColor

        for inline in Markdown.parse(text) {
            guard let range = attributedRange(inline.range, source: text, attributed: attributed) else {
                continue
            }

            switch inline.kind {
                case .heading(let level):
                    attributed[range].font = Typography.heading(level)

                case .quote:
                    attributed[range].font = Typography.quote
                    attributed[range].foregroundColor = baseColor.opacity(Style.Opacity.muted)

                case .quoteMarker:
                    attributed[range].foregroundColor = baseColor.opacity(Style.Opacity.faint)

                case .codeBlock:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = baseColor.opacity(Style.Opacity.muted)

                case .codeFence:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = baseColor.opacity(Style.Opacity.washed)

                case .strong:
                    attributed[range].font = Typography.prose.weight(.semibold)

                case .emphasis:
                    attributed[range].font = Typography.prose.italic()

                case .inlineCode:
                    attributed[range].font = Typography.proseCode
                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.washed)

                case .strikethrough:
                    attributed[range].foregroundColor = baseColor.opacity( Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .syntax:
                    attributed[range].font = Typography.Prose.syntaxHidden
                    attributed[range].foregroundColor = .clear
            }
        }

        return attributed
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

struct TranscriptHeader: View {
    var transcript: Reference

    var body: some View {
        if let value = Transcript.with(transcript, { $0 }) {
            let elapsed = if let started = value.started, let stopped = value.stopped {
                Int(stopped.timeIntervalSince(started).rounded())
            } else {
                0
            }

            HStack(spacing: Style.Spacing.md) {
                Text(value.origin.type is Transcript.Type ? transcript.descriptor.name : "Overview Transcript")
                    .font(Typography.row.weight(.semibold))
                    .foregroundStyle(Style.Foreground.muted)
                    .lineLimit(1)

                if let started = value.started {
                    Text(started, style: .time)
                }

                if elapsed > 0 {
                    Text(elapsed < 60 ? "\(elapsed)s" : "\(elapsed / 60)m \(elapsed % 60)s")
                }
            }
            .font(Typography.row)
            .foregroundStyle(Style.Foreground.faint)
            .frame(height: 24)
        }
    }
}

struct TranscriptSection: View {
    var transcript: Reference
    var model: any Model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TranscriptHeader(transcript: transcript)

            LazyVStack(alignment: .leading, spacing: Style.Spacing.md) {
                ForEach(Transcript.with(transcript, { $0.entries }) ?? []) { entry in
                    TranscriptEntry(transcript: transcript, entry: entry, model: model)
                }
            }
            .padding(.top, Style.Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.vertical, Style.Spacing.md)
    }
}
