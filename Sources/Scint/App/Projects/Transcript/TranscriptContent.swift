import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptContent: Surface {
    var host: any Host
    var model: any Model

    @State private var position = ScrollPosition(edge: .bottom)

    var ref: Reference? {
        guard let ref = model.session.selection.structure, let context = ref.context
        else { return nil }
        return context.transcript
    }

    var last: AnyHashable? { ref.flatMap { _ in entries.last?.id } }

    var entries: [Transcript.Entry] {
        func thread(_ ref: Reference) -> [Transcript.Entry] {
            let entries = Transcript.with(ref, { $0.entries }) ?? []
            return entries + entries.flatMap { entry -> [Transcript.Entry] in
                guard case .transcript(let branch, _, _) = entry else { return [] }
                return thread(branch)
            }
        }

        if let ref {
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
        return []
    }

    var body: some View {
        if let ref {
            ZStack(alignment: .bottom) {
                ScrollView {
                    Color.clear.frame(height: 10)
                    TranscriptFactory.build(entries)
                    Color.clear.frame(height: 150)
                }
                .frame(maxWidth: .infinity)
                .scrollPosition($position)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .onChange(of: ref) { position.scrollTo(edge: .bottom) }
                .onChange(of: last) { position.scrollTo(edge: .bottom) }

                Rectangle()
                    .fill(Style.Background.canvas)
                    .frame(maxHeight: 164, alignment: .bottom)
                    .blur(radius: 16, opaque: false)
                    .blendMode(.darken)
                    .padding(.bottom, -32)
            }
        }
    }
}

