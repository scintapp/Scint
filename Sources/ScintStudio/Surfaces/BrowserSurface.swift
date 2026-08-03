import SwiftUI


struct SpaceContent: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        render(self, ContentMapper.parameters(model), ContentMapper.controls(model))
    }
}

struct SpaceTranscripts: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        render(self, TranscriptsMapper.parameters(model), TranscriptsMapper.controls(model))
    }
}

struct SpaceSettings: Surface {
    var panel: any Panel
    let model: any Model

    var body: some View {
        render(self, SpaceInspector.parameters(model), SpaceInspector.controls(model))
    }
}

