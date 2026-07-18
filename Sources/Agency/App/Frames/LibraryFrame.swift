import AgencyRuntime
import SwiftUI


struct LibraryFrame: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.app.inspector

        NavigationSplitView {
            agency.app.navigator.surface(agency)
                .environment(agency)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            agency.app.canvas.surface(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.state.presented) {
            agency.app.inspector.surface(agency)
                .environment(agency)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
    }
}
