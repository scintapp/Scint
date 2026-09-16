import SwiftUI


@Observable @MainActor final class EditorModel: Model {
    var editor: EditorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.editor = .init()
        self.navigator = .init()
        self.session = session
    }
}

struct EditorWindow: View {
    @Environment(ScintModel.self) var scint
    @Environment(EditorModel.self) var model

    var body: some View {
        NavigationSplitView {
            model.navigator.surface(model)
        } detail: {
            model.editor.surface(model)
        }
        .environment(scint)
        .environment(scint.app)
        .environment(scint.app.editor)
        .toolbar(removing: .title)
    }
}
