import AgencyRuntime
import SwiftUI


@Observable @MainActor final class EditorModel: Model {
    var actions: Actions
    var canvas: Canvas
    var inspector: Inspector
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.canvas = .init()
        self.inspector = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct Editor: View {
    @Environment(EditorModel.self) var editor

    var body: some View {
        @Bindable var inspector = editor.inspector

        editor.canvas.surface(editor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .toolbar(removing: .title)
            .inspector(isPresented: $inspector.state.presented) {
                editor.inspector.surface(editor)
                    .frame(maxWidth: 400, maxHeight: .infinity, alignment: .top)
                    .inspectorColumnWidth(ideal: 300, max: 440)
            }
    }
}
