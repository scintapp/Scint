import SwiftUI
import AgencyRuntime


@Observable final class StudioModel: Model {
    let navigator = Navigator()
//    let composer = Composer()
    let content = Content()
    let console = Console()
    let inspector = Inspector()
}

struct Studio: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var inspector = agency.studio.inspector

        NavigationSplitView {
            agency.studio.navigator.build(agency)
                .environment(agency)
        } detail: {
            agency.studio.content.build(agency)
                .environment(agency)
        }
        .inspector(isPresented: $inspector.presented) {
            agency.studio.inspector.build(agency)
                .environment(agency)
        }
    }
}

