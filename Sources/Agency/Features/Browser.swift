import SwiftUI
import AgencyRuntime


struct BrowserToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { NavigationControls() }
        ToolbarItem(placement: .navigation) { SpaceControls() }.sharedBackgroundVisibility(.hidden)
        ToolbarSpacer(.flexible, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) { LayoutPicker() }
    }
}

struct Browser: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var navigator = agency.studio.navigator
        @Bindable var inspector = agency.studio.inspector
        @Bindable var console = agency.studio.console

        NavigationSplitView {
            navigator.build(agency)
                .environment(agency)
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
            .environment(agency)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.presented) {
            inspector.build(agency)
                .environment(agency)
                .ignoresSafeArea(.container, edges: .top)
                .inspectorColumnWidth(min: 200, ideal: 330, max: 440)
                .toolbar { InspectorToolbar() }
        }
    }
}
