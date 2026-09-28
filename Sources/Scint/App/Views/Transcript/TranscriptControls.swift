import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptControls: View {
    var panel: any Panel
    var model: any Model

    var transcript: Reference? { model.session.transcript }

    var entries: [(id: AnyHashable, entry: TranscriptEntry)] {
        func thread(_ ref: Reference) -> [Transcript.Entry] {
            let entries = Transcript.with(ref, { $0.entries }) ?? []
            return entries + entries.flatMap { entry -> [Transcript.Entry] in
                guard case .transcript(let branch, _, _) = entry else { return [] }
                return thread(branch)
            }
        }

        var entries: [(id: AnyHashable, entry: TranscriptEntry)] = []
        guard let transcript else { return [] }

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
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: Style.Spacing.page) {
                    ForEach(entries, id: \.id) { item in
                        item.entry
                            .frame(maxWidth: Typography.Prose.readableWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
        .safeAreaBar(edge: .top) {
            TranscriptMenu(panel: panel, model: model)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

