import SwiftUI
import AgencyRuntime


@Observable final class StudioModel: Feature {
    let navigator = Navigator()
    let content = Content()
    let console = Console()
    let inspector = Inspector()
}

struct Studio: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var navigator = agency.studio.navigator
        @Bindable var content = agency.studio.console
        @Bindable var inspector = agency.studio.inspector
        @Bindable var console = agency.studio.console

        NavigationSplitView {
            navigator.build(agency)
                .ignoresSafeArea(.container, edges: .vertical)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 330)
                .toolbar(removing: .sidebarToggle)
                .toolbar { NavigatorToolbar() }

        } detail: {
            VerticalSplit($console.presented, position: $console.position) {
                agency.studio.content.build(agency)
            } bottom: {
                agency.studio.console.build(agency)
            }
            .ignoresSafeArea(.container, edges: .top)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .title)
            .toolbar { ContentToolbar(presented: $content.presented) }
        }
        .inspector(isPresented: $inspector.presented) {
            inspector.build(agency)
        }
    }
}

