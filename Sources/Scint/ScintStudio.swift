import SwiftUI


struct Studio: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var studio = scint.studio

        NavigationSplitView {
            studio.navigator.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            studio.content.surface(studio)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $studio.inspector.state.presented) {
            studio.inspector.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}
