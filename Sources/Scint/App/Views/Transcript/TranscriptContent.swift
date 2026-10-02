import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptThread: View {
    var ref: Reference

    var entries: [Transcript.Entry] {
        func thread(_ ref: Reference) -> [Transcript.Entry] {
            let entries = Transcript.with(ref, { $0.entries }) ?? []
            return entries + entries.flatMap { entry -> [Transcript.Entry] in
                guard case .transcript(let branch, _, _) = entry else { return [] }
                return thread(branch)
            }
        }

        return thread(ref)
            .filter { entry in
                switch entry {
                    case .record(let record, _): record.fields["channel"] != .string("reasoning")
                    case .signal(_, .fail, _): true
                    case .signal, .transcript: false
                }
            }
            .enumerated()
            .sorted { ($0.element.created, $0.offset) < ($1.element.created, $1.offset) }
            .map(\.element)
    }

    var runs: [[Transcript.Entry]] {
        entries.reduce(into: []) { runs, entry in
            switch (runs.last?.last, entry) {
                case (.record(let last, _)?, .record(let next, _)) where last.fields["type"] == .string("method") && next.fields["type"] == .string("method"):
                    runs[runs.count - 1].append(entry)
                default:
                    runs.append([entry])
            }
        }
    }

    var body: some View {
        ForEach(runs, id: \.first?.id) { run in
            TranscriptFactory.build(run)
                .frame(maxWidth: Typography.Prose.readableWidth)
        }
    }
}

struct TranscriptContent: Surface {
    var panel: any Panel
    var model: any Model

    @State private var position = ScrollPosition(edge: .bottom)

    var root: Reference? { model.session.selection.structure?.context?.transcript }
    var last: AnyHashable? { root.flatMap { TranscriptThread(ref: $0).runs.last?.first?.id } }

    var body: some View {
        if let root {
            ZStack(alignment: .bottom) {
                ScrollView {
                    Color.clear.frame(height: 10)
                    LazyVStack(spacing: 24) {
                        TranscriptThread(ref: root)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    Color.clear.frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                .scrollPosition($position)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .onChange(of: root) { position.scrollTo(edge: .bottom) }
                .onChange(of: last) { position.scrollTo(edge: .bottom) }

                Rectangle()
                    .fill(Style.Background.canvas)
                    .frame(maxHeight: 64, alignment: .bottom)
                    .blur(radius: 10, opaque: false)
                    .blendMode(.darken)
                    .padding(.bottom, -32)
            }
        }
    }
}

