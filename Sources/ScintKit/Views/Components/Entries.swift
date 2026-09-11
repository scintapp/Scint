import SwiftUI


struct TranscriptEntry: View {
    var transcript: Reference
    var entry: Transcript.Entry
    var model: any Model
    var inputMaxWidth: CGFloat? = nil

    var input: String? {
        switch entry {
            case .record(let chunk, _) where chunk.origin.type == Material.self:
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

    func sentence(_ call: ToolCall) -> String {
        let (one, all) = switch call.namespace {
            case .content: ("a document", "documents")
            case .interfaces: ("an interface", "interfaces")
            case .structures: ("a structure", "structures")
        }

        return switch call {
            case .catalog(_, .list): "Listed \(all)"
            case .catalog(_, .search): "Searched \(all)"
            case .catalog(_, .describe): "Described \(one)"
            case .catalog(_, .update): "Relabeled \(one)"
            case .content(.read), .interface(.read), .structure(.read): "Read \(one)"
            case .content(.write): "Edited \(one)"
            case .content(.create), .structure(.create): "Created \(one)"
            case .structure(.add): "Added to \(one)"
            case .structure(.remove): "Removed from \(one)"
            case .structure(.start): "Started \(one)"
            case .structure(.stop): "Stopped \(one)"
            case .interface(.call): "Ran \(one)"
        }
    }

    var body: some View {
        Group {
            if let input, !input.isEmpty {
                HStack {
                    Spacer()

                    TextBlock(content: input)
                        .foregroundStyle(Style.Foreground.subtle)
                        .padding(.horizontal, Style.Spacing.lg)
                        .padding(.vertical, Style.Spacing.lg)
                        .background(Style.Shape.medium.fill(Style.Background.overlay))
                        .overlay(
                            Style.Shape.medium
                                .strokeBorder(Style.Border.group, lineWidth: 0.5)
                        )
                        .frame(maxWidth: inputMaxWidth, alignment: .trailing)
                }
            } else {
                switch entry {
                    case .record(let chunk, _) where field(chunk.value, "type") == "reasoning":
                        TextBlock(content: field(chunk.value, "text") ?? "", reasoning: true)

                    case .record(let chunk, _) where field(chunk.value, "type") == "tool":
                        HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.md) {
                            Iconography.icon(for: entry, size: Style.Dimension.icon)

                            Text(field(chunk.value, "name").flatMap(ToolCall.named).map(sentence) ?? "Called a tool")

                            Spacer(minLength: 0)

                            // Completing is what a call is expected to do; only a call that didn't earns a badge.
                            if let status = field(chunk.value, "status"), status != "completed" {
                                Badge(label: status.capitalized, tint: Style.Foreground.muted)
                                    .fixedSize()
                            }
                        }
                        .foregroundStyle(Style.Foreground.muted)

                    case .record(let chunk, _) where field(chunk.value, "type") != nil:
                        TextBlock(content: field(chunk.value, "text") ?? "")

                    case .record(let chunk, _):
                        VStack(alignment: .leading, spacing: Style.Spacing.md) {
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
        .font(Typography.prose)
        .foregroundStyle(Style.Foreground.primary)
        .lineSpacing(Style.Spacing.markdownLineSpacing)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
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
