import AgencyRuntime
import SwiftUI


struct CanvasCompose: Surface {
    @Environment(AgencyModel.self) var agency
    var panel: any Panel

    var transcript: Transcript? {
        guard let active = agency.session.active, let transcript = Transcript.with(active, { $0 })
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

            ComposerInput()
                .frame(maxWidth: 660, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) { PathBar() }
    }
}

struct CanvasBrowse: Surface {
    @Environment(AgencyModel.self) var agency
    var panel: any Panel

    var body: some View {
        view(self, BrowserMap.parameters(agency), BrowserMap.controls(agency))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaBar(edge: .top, alignment: .leading) { ActionsBar() }
    }
}

struct CanvasEdit: Surface {
    @Environment(AgencyModel.self) var agency
    var panel: any Panel

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 16)
            VStack {
                if let sheet = agency.session.active {
                    EditorComponent(sheet)
                        .id(sheet)
                        .frame(maxWidth: 680, alignment: .topLeading)
                } else {
                    Text("Nothing Open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            Color.clear.frame(height: 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top, alignment: .leading) { ActionsBar() }
    }
}
