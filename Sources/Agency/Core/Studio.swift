import AgencyRuntime
import SwiftUI


@Observable @MainActor final class StudioModel {
    let actions = Actions()
    let canvas = Canvas()
    let inspector = Inspector()
    let navigator = Navigator()
    let utility = Utility()

    let browser = Browser()
    let dashboard = Dashboard()
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
                .navigationSplitViewColumnWidth(ideal: 280)
                .scrollEdgeEffectStyle(.hard, for: .top)
        } detail: {
            agency.studio.canvas.view(agency)
                .environment(agency)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .toolbar { agency.studio.canvas.toolbar() }
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .scrollEdgeEffectStyle(.hard, for: .top)
                .inspectorColumnWidth(ideal: 340)
                .toolbar(removing: .sidebarToggle)
        }
    }
}
