import SwiftUI
import AgencyRuntime


@Observable @MainActor final class StudioModel {
    let navigator = Navigator()
    let content = Content()
    let console = Console()
    let inspector = Inspector()
}

struct Studio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 330 )
        } detail: {
            agency.studio.content.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 300, ideal: 560 )
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .inspectorColumnWidth(min: 260, ideal: 340, max: 460)
        }
    }
}

