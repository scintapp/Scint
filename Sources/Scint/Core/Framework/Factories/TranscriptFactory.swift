import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct TranscriptFactory {
    @ViewBuilder static func build(_ entries: [Transcript.Entry]) -> some View {
        Group {
            switch entries.first {
                case .record(let record, _)? where record.fields["type"] == .string("method"): TranscriptActivity(entries: entries)
                case let entry?: build(entry)
                case nil: EmptyView()
            }
        }
        .font(Typography.body)
        .foregroundStyle(Style.Foreground.primary)
        .lineSpacing(Typography.Prose.lineSpacing)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
    }

    @ViewBuilder static func build(_ entry: Transcript.Entry) -> some View {
        switch entry {
            case .record(let record, let created):
                switch (record.fields["type"], record.fields["channel"]) {
                    case (.string("input")?, _): EntryControls(created: created) { build(record) }
                    case (.string("output")?, nil): EntryControls(created: created, trailing: false) { build(record) }
                    default: build(record)
                }
            case .signal(_, let signal, _):
                build(signal)
            case .transcript:
                EmptyView()
        }
    }

    @ViewBuilder static func build(_ record: Record) -> some View {
        switch (record.fields["type"], record.fields["channel"], record.fields["content"]) {
            case (.string("input")?, _, .string("")?):
                EmptyView()

            case (.string("input")?, _, .string(let text)?):
                InputEntry(content: text)

            case (.string("output")?, .string("reasoning")?, .string(let text)?):
                ReasoningEntry(thoughts: [text])

            case (.string("output")?, _, .string(let text)?):
                OutputEntry(content: text)

            case (.string("output")?, _, let content?):
                RecordEntry(cards: [], content: content.stringRepresentation)

            case (.string("method")?, _, _):
                ToolEntry(record: record)

            case (.string("error")?, _, let content):
                NoticeEntry(content: content?.stringRepresentation ?? "Something went wrong")

            default:
                EmptyView()
        }
    }

    @ViewBuilder static func build(_ signal: Signal) -> some View {
        switch signal {
            case .fail(let branch):
                let text = (Transcript.with(branch, { $0.records.last?.fields["content"]?.stringRepresentation }) ?? nil) ?? ""
                NoticeEntry(content: text.isEmpty ? "Stopped with an error" : text)
            case .compose, .start, .update, .complete, .cancel: EmptyView()
        }
    }
}
