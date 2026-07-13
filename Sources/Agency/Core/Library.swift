import AgencyRuntime
import SwiftUI


@Observable @MainActor final class LibraryModel {
    let actions = Actions()
    let content = Canvas()
    let navigator = Navigator()
    let inspector = Inspector()
}

struct Library: Feature {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        return NavigationSplitView {
            agency.studio.navigator.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationSplitViewColumnWidth(ideal: 280)

        } detail: {
            agency.studio.canvas.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(.container, edges: .top)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.view(agency)
                .environment(agency)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .inspectorColumnWidth(min: 260, ideal: 340, max: 520)
        }
    }
}
