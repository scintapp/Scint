import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptThread: View {
    var ref: Reference

    var entries: [Transcript.Entry] { Transcript.with(ref, { $0.entries }) ?? [] }

    var body: some View {
        ForEach(entries) { entry in
            TranscriptFactory.build(entry)
                .frame(maxWidth: Typography.Prose.readableWidth)
        }
    }
}

struct TranscriptContent: Surface {
    var panel: any Panel
    var model: any Model

    @State private var position = ScrollPosition(edge: .bottom)

    var root: Reference? { model.session.selection.structure?.context?.transcript }
    var last: AnyHashable? { root.flatMap { root in Transcript.with(root, { $0.entries.last?.id }) ?? nil } }

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

