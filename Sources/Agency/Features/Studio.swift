import SwiftUI
import AgencyRuntime


struct Studio: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var navigator = agency.studio.navigator
        @Bindable var inspector = agency.studio.inspector
        @Bindable var console = agency.studio.console
        @Bindable var content = agency.studio.console

        NavigationSplitView {
            navigator.build(agency)
                .environment(agency)
                .ignoresSafeArea(.container, edges: .vertical)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 330)
                .toolbar(removing: .sidebarToggle)
                .toolbar { NavigatorToolbar() }

        } detail: {
            VerticalSplit(
                $console.presented,
                position: $console.position,
                collapsedHeight: 30,
                minTopHeight: 0,
                minBottomHeight: 0
            ) {
                agency.studio.content.build(agency)
            } bottom: {
                agency.studio.console.build(agency)
            }
            .ignoresSafeArea(.container, edges: .top)
            .environment(agency)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .title)
            .toolbar { ContentToolbar(presented: $content.presented) }
        }
        .inspector(isPresented: $inspector.presented) {
            inspector.build(agency)
                .environment(agency)
                .ignoresSafeArea(.container, edges: .top)
                .inspectorColumnWidth(min: 200, ideal: 330, max: 440)
                .toolbar(removing: .sidebarToggle)
                .toolbar { InspectorToolbar() }
        }
    }
}
