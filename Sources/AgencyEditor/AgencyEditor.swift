import SwiftUI
import AgencyRuntime


@main
struct AgencyEditor: App {
    @State private var editor: EditorModel?

    func load() async {
        guard editor == nil else { return }
        do { try await Runtime.shared.load() } catch { print(error) }
        guard let workspace = Runtime.shared.workspaces.first(where: { $0.descriptor.framing == .editor })
            ?? Runtime.shared.workspaces.first else { return }
        let model = EditorModel(workspace)
        let ref = Sheet.new(model.session.workspace, name: "Untitled")
        model.open(ref)
        editor = model
    }

    var body: some Scene {
        WindowGroup("Untitled", id: "editor") {
            if let editor {
                EditorFrame()
                    .environment(editor)
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }
        .defaultSize(width: 1_180, height: 820)
    }
}
