import SwiftUI


struct ComposerSurface: Surface {
    var panel: any Panel
    var model: any Model

    var transcript: Transcript? {
        guard
            let focused = model.session.transcript,
            let transcript = Transcript.with(focused, { $0 })
                else { return nil }
        return transcript
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptSurface(panel: panel, model: model)
          
            ComposerInput(model: model)
                .frame(maxWidth: 660, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}


