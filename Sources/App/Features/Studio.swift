import SwiftUI


@Observable @MainActor final class StudioModel {
    let actions = Actions()
    let console = Console()

    let sidebar = Navigator()
    let content = Content()
    let detail = Detail()
    let inspector = Inspector()

    let editor = EditorDetail()
    let browser = BrowserDetail()
    let composer = ComposerDetail()
}

struct Studio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.sidebar.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 360)
        } content: {
            agency.studio.content.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(ideal: 0)
                .navigationSplitViewStyle(.prominentDetail)
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

