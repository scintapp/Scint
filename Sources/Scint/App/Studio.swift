import SwiftUI
import ScintComponents


@Observable @MainActor final class StudioModel: Model {
    var content: ContentPanel
    var inspector: InspectorPanel
    var navigator: NavigatorPanel
    var session: Session

    init(_ session: Session) {
        self.content = .init()
        self.inspector = .init()
        self.navigator = .init()
        self.session = session
    }
}

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

struct Studio: View {
    @Environment(ScintModel.self) var scint
    @Environment(StudioModel.self) var model

    var body: some View {
        NavigationSplitView {
            model.navigator.surface(model)
        } detail: {
            model.content.surface(model)
        }
        .inspector(isPresented: model.inspector.bindable.presented) {
            model.inspector.surface(model)
                .background(Style.Background.canvas)
                .inspectorColumnWidth(min: 240, ideal: 320, max: 480)
                .ignoresSafeArea(.all, edges: .top)
        }
        .environment(scint)
        .environment(scint.app)
        .environment(scint.app.studio)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}
