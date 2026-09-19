import ScintComponents
import SwiftUI


struct TranscriptContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        if let ref = model.session.opened.transcript { return ref }
        else if let ref = model.session.selection.content, ref.type is Transcript.Type { return ref }
        else { return nil }
    }

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 9)
            LazyVStack(spacing: Style.Spacing.entry) {
                if let transcript = model.session.transcript {
                    let records = (Transcript.with(transcript, { $0.entries }) ?? []).filter { entry in
                        if case .record = entry { true } else { false }
                    }

                    ForEach(records) { entry in
                        TranscriptEntry(transcript: transcript, entry: entry, model: model)
                            .frame(maxWidth: Style.Prose.readableWidth)
                    }
                }
            }
            .frame(maxWidth: Style.Prose.readableWidth, maxHeight: .infinity, alignment: .top)
            .padding(8)
        }
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .padding(.bottom, 24)

        InputBar(model: model, onSend: {})
            .padding([.horizontal, .bottom], 10)
    }
}

