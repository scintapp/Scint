import SwiftUI


@Observable @MainActor final class StudioModel {
    let navigator = Navigator()
    let detail = Detail()
    let console = Console()
    let inspector = Inspector()
    let palette = Palette()

    let editor = DetailEditor()
    let browser = DetailBrowser()
    let composer = DetailComposer()

    enum Model { case sidebar, detail, console, inspector, palette }
}

struct Studio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 360)
        } detail: {
            agency.studio.detail.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(ideal: 300)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .inspectorColumnWidth(min: 240, ideal: 360, max: 480)
        }
    }
}

