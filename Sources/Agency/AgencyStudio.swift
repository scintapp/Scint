import SwiftUI


struct Studio: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 360)
        } detail: {
            agency.studio.content.view(agency)
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

