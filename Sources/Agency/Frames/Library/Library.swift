import AgencyRuntime
import SwiftUI


@Observable @MainActor final class LibraryModel: Model {
    var actions: Actions
    var canvas: Canvas
    var navigator: Navigator
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.canvas = .init()
        self.navigator = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct Library: View {
    @Environment(LibraryModel.self) var library

    var body: some View {
        NavigationSplitView {
            library.navigator.surface(library)
                .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            library.canvas.surface(library)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(removing: .title)
        }
    }
}
