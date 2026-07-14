import AgencyRuntime
import SwiftUI


@MainActor struct Features {
    let browser = Browser()
    let editor = Editor()
    let composer = Composer()
}

@Observable @MainActor final class StudioModel {
    let features = Features()
    let actions = Actions()
    let canvas = Canvas()
    let inspector = Inspector()
    let navigator = Navigator()
    let console = Console()
}

struct Studio: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            agency.studio.canvas.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300)
        }
    }
}
