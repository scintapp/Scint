import SwiftUI


struct TranscriptSurface: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        ScrollView {
            VStack(spacing: Style.Spacing.xxl) {
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
            Color.clear.frame(height: 128)
        }
        .scrollEdgeEffectStyle(.hard, for: .vertical)
    }
}
