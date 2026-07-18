import AgencyRuntime
import SwiftUI


struct ComposerComposeCanvas: Surface {
    var panel: any Panel
    let model: any Model

    var transcript: Transcript? {
        guard let active = model.session.active, let transcript = Transcript.with(active, { $0 })
        else { return nil }
        return transcript
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                Color.clear.frame(height: 32)

                VStack(alignment: .leading, spacing: 16) {
                    if transcript != nil {
                        ForEach(transcript!.entries) { entry in
                            TranscriptEntry(entry: entry)
                        }
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: 660, alignment: .top)

                Color.clear.frame(height: 64)
            }

            ComposerInput(model: model)
                .frame(maxWidth: 660, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) { PathBar(model: model) }
    }
}

struct ComposerReviewCanvas: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        ZStack(alignment: .bottom) {
            EmptyView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) { ActionsBar(model: model) }
    }
}

