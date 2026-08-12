import SwiftUI


struct ScintStudio: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var studio = scint.studio

        NavigationSplitView {
            studio.sidebar.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            studio.content.surface(studio)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(removing: .title)
                .safeAreaBar(edge: .top) {
                    HStack(alignment: .center) {
                        PathBar(model: studio)
                        Spacer()
                        BadgesBar(model: studio)
                    }
                    .frame(maxHeight: 30)
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) { NavigationControls(model: studio) }
                }
        }
        .inspector(isPresented: $studio.inspector.state.presented) {
            studio.inspector.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}
