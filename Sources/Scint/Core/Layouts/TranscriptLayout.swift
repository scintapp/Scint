import SwiftUI


enum Attribute {
    static func text(_ text: String, reasoning: Bool = false) -> AttributedString {
        let base = reasoning ? Style.Foreground.faint : Style.Foreground.base
        var attributed = AttributedString(text)
        attributed.font = reasoning ? Typography.prose.italic() : Typography.prose
        attributed.foregroundColor = base

        for span in Markdown.scan(text).spans {
            guard let range = range(span.range, source: text, attributed: attributed) else {
                continue
            }

            switch span.kind {
                case .heading(let level):
                    attributed[range].font = Typography.heading(level)

                case .quote:
                    attributed[range].font = Typography.quote
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .quoteMarker, .listMarker:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .checkbox(let checked):
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(
                        checked ? Style.Opacity.muted : Style.Opacity.faint
                    )

                case .completed:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .codeBlock:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .codeFence:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.washed)

                case .strong:
                    attributed[range].font = Typography.prose.weight(.semibold)

                case .emphasis:
                    attributed[range].font = Typography.prose.italic()

                case .inlineCode:
                    attributed[range].font = Typography.proseCode
                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.washed)

                case .strikethrough:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .linkLabel:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.strong)
                    attributed[range].underlineStyle = .single

                case .linkURL:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .syntax:
                    attributed[range].font = Typography.Prose.syntaxHidden
                    attributed[range].foregroundColor = .clear
            }
        }

        return attributed
    }

    static func range(_ range: NSRange, source: String, attributed: AttributedString) -> Range<AttributedString.Index>? {
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

struct TranscriptEntry: View {
    var transcript: Reference
    var entry: Transcript.Entry
    var model: any Model

    var input: String? {
        switch entry {
            case .record(let chunk, _) where chunk.origin.type == Material.self:
                chunk.value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
                    case .record(let chunk, _) where field(chunk.value, "type") == "reasoning":
                        Text(Attribute.text(field(chunk.value, "text") ?? "", reasoning: true))

                    case .record(let chunk, _) where field(chunk.value, "type") == "tool":
                        HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.md) {
                            Iconography.icon(for: Intent.dispatch, size: Style.Spacing.lg)

                            Text(field(chunk.value, "name") ?? "tool")
                                .font(Typography.cardDetail(.monospaced))
                                .foregroundStyle(Style.Foreground.subtle)

                            if let status = field(chunk.value, "status") {
                                Text(status)
                                    .font(Typography.label)
                                    .foregroundStyle(Style.Foreground.faint)
                            }

                            Spacer(minLength: 0)
                        }

                    case .record(let chunk, _) where field(chunk.value, "type") != nil:
                        Text(Attribute.text(field(chunk.value, "text") ?? ""))

                    case .event, .record, .transcript:
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

    private func field(_ value: Value, _ name: String) -> String? {
        guard case .collection(let fields) = value, let found = fields[name] else { return nil }
        let text = found.rendered.joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}
