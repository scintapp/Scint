import SwiftUI
import AgencyRuntime


@main
struct AgencyEditor: App {
    @State private var agency: AgencyModel?
    @State private var sheet: Reference?

    func load() async {
        guard agency == nil else { return }
        do { try await Runtime.shared.load() } catch { print(error) }
        let model = AgencyModel(Runtime.shared.workspace)
        await model.load()
        let ref = Sheet.new(model.session.workspace, name: "Untitled")
        model.open(ref)
        agency = model
        sheet = ref
    }

    var body: some Scene {
        WindowGroup("Untitled", id: "editor") {
            if let agency, let sheet {
                EditorFrame(sheet: sheet)
                    .environment(agency)
                    .onAppear(perform: { ShortcutManager.shared.register(agency: agency) } )
                    .focusable(false)
            } else { ProgressView().task { await load() } }
        }
        .defaultSize(width: 1_180, height: 820)
    }
}
