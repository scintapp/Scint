import AgencyRuntime
import SwiftUI


@Observable @MainActor final class StudioModel {
    let actions = Actions()
    let canvas = Canvas()
    let inspector = Inspector()
    let navigator = Navigator()
    let utility = Utility()

    let browser = Browser()
    let composer = Composer()
    let editor = Editor()
}

struct Studio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationSplitViewColumnWidth(ideal: 280)
        } detail: {
            agency.studio.canvas.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .inspectorColumnWidth(ideal: 340)
        }
    }
}
