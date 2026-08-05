import SwiftUI


@Observable @MainActor final class StudioModel: Model {
    var sidebar: StudioSidebar
    var canvas: StudioCanvas
    var console: StudioConsole
    var inspector: StudioInspector
    var files: FileProvider
    var session: Session

    init(_ workspace: Reference) {
        self.sidebar = .init()
        self.canvas = .init()
        self.console = .init()
        self.inspector = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct ScintStudio: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var studio = scint.studio

        NavigationSplitView {
            studio.sidebar.panel(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VSplit($studio.console.state.presented, $studio.console.state.position) {
                studio.canvas.panel(studio)
            } bottom: {
                studio.console.panel(studio)
            }
            .ignoresSafeArea(.container, edges: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(removing: .title)
        }
        .inspector(isPresented: $studio.inspector.state.presented) {
            studio.inspector.panel(studio)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
        .environment(scint)
    }
}

