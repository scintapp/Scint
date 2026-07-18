import AgencyRuntime
import SwiftUI



@Observable @MainActor final class StudioModel: Model {
    var actions: Actions
    var canvas: Canvas
    var navigator: Navigator
    var inspector: Inspector
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.canvas = .init()
        self.navigator = .init()
        self.inspector = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct Studio: View {
    @Environment(StudioModel.self) var studio

    var body: some View {
        @Bindable var inspector = studio.inspector

        NavigationSplitView {
            studio.navigator.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            studio.canvas.surface(studio)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .title)
        }
        .inspector(isPresented: $inspector.state.presented) {
            studio.inspector.surface(studio)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .inspectorColumnWidth(ideal: 300, max: 440)
        }
    }
}
