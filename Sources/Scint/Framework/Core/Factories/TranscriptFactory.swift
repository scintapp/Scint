import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct TranscriptFactory {
    @ViewBuilder static func build(_ entries: [Entry]) -> some View {
        let runs = entries.reduce(into: [[Entry]]()) { runs, entry in
            switch (runs.last?.last, entry) {
                case (.record(let last, _)?, .record(let next, _)) where last.fields["type"] == .string("method") && next.fields["type"] == .string("method"):
                    runs[runs.count - 1].append(entry)
                default:
                    runs.append([entry])
            }
        }

        LazyVStack(spacing: 24) {
            ForEach(runs, id: \.first?.id) { run in
                Group {
                    switch run.first {
                        case .record(let record, _)? where record.fields["type"] == .string("method"):
                            TranscriptActivity(entries: run)

                        case let entry?:
                            build(entry)

                        case nil:
                            EmptyView()
                    }
                }
                .font(Typography.body)
                .foregroundStyle(Style.Foreground.primary)
                .lineSpacing(Typography.Prose.lineSpacing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
                .frame(maxWidth: Typography.Prose.readableWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder static func build(_ entry: Entry) -> some View {
        switch entry {
            case .record(let record, let created):
                switch (record.fields["type"], record.fields["channel"]) {
                    case (.string("input")?, _):
                        EntryControls(created: created) { build(record) }

                    case (.string("output")?, nil):
                        EntryControls(created: created, trailing: false) { build(record) }

                    default:
                        build(record)
                }

            case .signal(_, let signal, _):
                switch signal {
                    case .compose, .start, .update, .complete, .cancel, .fail:
                        EmptyView()
                }

            case .transcript:
                EmptyView()
        }
    }

    @ViewBuilder static func build(_ record: Record) -> some View {
        switch (record.fields["type"], record.fields["channel"], record.fields["content"]) {
            case (.string("input")?, _, .string("")?):
                EmptyView()

            case (.string("input")?, _, .string(let text)?):
                EntryInput(content: text)

            case (.string("output")?, .string("reasoning")?, .string(let text)?):
                EntryReasoning(thoughts: [text])

            case (.string("output")?, _, .string(let text)?):
                EntryOutput(content: text)

            case (.string("output")?, _, let content?):
                EntryRecord(cards: [], content: content.stringRepresentation)

            case (.string("method")?, _, _):
                EntryTool(record: record)

            case (.string("error")?, _, let content):
                EntryNotice(content: content?.stringRepresentation ?? "Something went wrong")

            default:
                EmptyView()
        }
    }
}
