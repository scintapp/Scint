import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        if let ref = model.session.opened.transcript { return ref }
        else if let ref = model.session.selection.content, ref.type is Transcript.Type { return ref }
        else { return nil }
    }

    var context: Composition? { model.session.selection.structure?.context }

    var entries: [(id: AnyHashable, entry: TranscriptEntry)] {
        guard let transcript = model.session.transcript else { return [] }

        func thread(_ ref: Reference) -> [Transcript.Entry] {
            let entries = Transcript.with(ref, { $0.entries }) ?? []
            return entries + entries.flatMap { entry -> [Transcript.Entry] in
                guard case .transcript(let branch, _, _) = entry else { return [] }
                return thread(branch)
            }
        }

        var entries: [(id: AnyHashable, entry: TranscriptEntry)] = []
        for item in thread(transcript).enumerated().sorted(by: { ($0.element.created, $0.offset) < ($1.element.created, $1.offset) }) {
            guard let entry = TranscriptEntry(item.element) else { continue }
            if case .activity(let next) = entry, case .activity(let run)? = entries.last?.entry {
                entries[entries.count - 1].entry = .activity(ActivityEntry(thoughts: run.thoughts + next.thoughts, tools: run.tools + next.tools))
            } else {
                entries.append((item.element.id, entry))
            }
        }
        return entries
    }

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 10)
            LazyVStack(spacing: Style.Spacing.page) {
                ForEach(entries, id: \.id) { item in
                    item.entry
                        .frame(maxWidth: Typography.Prose.readableWidth)
                }

                if let context, context.state == .working {
                    WorkingEntry(context: context)
                        .frame(maxWidth: Typography.Prose.readableWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Color.clear.frame(height: 150)
        }
        .frame(maxWidth: .infinity)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
