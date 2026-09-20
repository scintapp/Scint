import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptEntry: View {
    var transcript: Reference
    var entry: Transcript.Entry
    var model: any Model

    var input: String? {
        switch entry {
            case .record(let chunk, _) where chunk.origin.type == Document.self:
                chunk.value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                nil
        }
    }

    func field(_ value: Value, _ name: String) -> String? {
        guard case .collection(let fields) = value, let found = fields[name] else { return nil }
        let text = found.rendered.joined(separator: " ")
        return text.isEmpty ? nil : text
    }


    var body: some View {
        Group {
            if let input, !input.isEmpty {
                TextBlock(content: input, hugs: true)
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(.horizontal, Style.Spacing.inset)
                    .padding(.vertical, Style.Spacing.label)
                    .background(Style.Shape.card.fill(Style.Background.surface))
                    .overlay(
                        Style.Shape.card
                            .strokeBorder(
                                Style.Border.hairline,
                                lineWidth: 0.5
                            )
                    )
                    .frame(maxWidth: 400, alignment: .trailing)
            } else {
                switch entry {
                    case .record(let chunk, _) where field(chunk.value, "type") == "reasoning":
                        TextBlock(content: field(chunk.value, "text") ?? "", reasoning: true)

                    case .record(let chunk, _) where field(chunk.value, "type") == "tool":
                        HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.label) {
                            Iconography.icon(for: entry, size: Style.Dimension.icon)

                            Text(field(chunk.value, "name").flatMap(Operation.named).map(\.sentence) ?? "Called a tool")

                            Spacer(minLength: 0)

                            if let status = field(chunk.value, "status"), status != "completed" {
                                Badge(label: status.capitalized, tint: Style.Foreground.secondary)
                                    .fixedSize()
                            }
                        }
                        .foregroundStyle(Style.Foreground.secondary)

                    case .record(let chunk, _) where field(chunk.value, "type") != nil:
                        TextBlock(content: field(chunk.value, "text") ?? "")

                    case .record(let chunk, _):
                        VStack(alignment: .leading, spacing: Style.Spacing.label) {
                            if chunk.origin.type == Command.self || chunk.origin.type == Artifact.self {
                                Card(ref: chunk.origin, style: .group)
                            }
                            if case .reference(let ref) = chunk.value {
                                Card(ref: ref, style: .group)
                            } else {
                                TextBlock(content: chunk.value.rendered.joined(separator: "\n"))
                            }
                        }

                    case .event, .transcript:
                        EmptyView()
                }
            }
        }
        .font(Typography.body)
        .foregroundStyle(Style.Foreground.primary)
        .lineSpacing(Style.Prose.lineSpacing)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .transcript = entry { return }
            model.select(transcript)
            model.open(transcript)
        }
    }
}

extension TranscriptEntry {
    init?(transcript: Reference, entryId: UUID, model: any Model) {
        guard let entry = Transcript.with(transcript, { record in
            record.entries.first {
                if case .record(let chunk, _) = $0 { return chunk.key.id == entryId }
                return false
            }
        }) ?? nil else { return nil }
        self.init(transcript: transcript, entry: entry, model: model)
    }
}
