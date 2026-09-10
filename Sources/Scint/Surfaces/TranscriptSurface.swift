import SwiftUI


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

    private func field(_ value: Value, _ name: String) -> String? {
        guard case .collection(let fields) = value, let found = fields[name] else { return nil }
        let text = found.rendered.joined(separator: " ")
        return text.isEmpty ? nil : text
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
}

struct TranscriptSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Style.Spacing.xxl) {
                if let transcript = model.session.transcript {
                    ForEach(Transcript.with(transcript, { $0.entries }) ?? []) { entry in
                        TranscriptEntry(transcript: transcript, entry: entry, model: model)
                            .padding(.vertical, Style.Spacing.xl)
                            .frame(maxWidth: 680)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }
}
