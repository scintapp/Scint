import SwiftUI


@Observable @MainActor final class StudioModel: Model {
    var actions: Actions
    var library: StudioLibrary
    var canvas: StudioCanvas
    var inspector: StudioInspector
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.canvas = .init()
        self.library = .init()
        self.inspector = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var Scint
    @Environment(StudioModel.self) var studio

    var body: some View {
        @Bindable var inspector = studio.inspector

        NavigationSplitView {
            studio.library.panel(studio)
                .environment(Scint)
                .environment(studio)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            studio.canvas.panel(studio)
                .environment(Scint)
                .environment(studio)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.state.presented) {
            studio.inspector.panel(studio)
                .environment(Scint)
                .environment(studio)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
    }
}
